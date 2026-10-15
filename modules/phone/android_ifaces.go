package main

import (
	"encoding/binary"
	"net"
	"os"
	"sort"
	"strconv"
	"syscall"

	"golang.org/x/sys/unix"
	"tailscale.com/net/netmon"
)

func init() {
	if _, err := os.Stat("/system/bin/linker64"); err == nil {
		netmon.RegisterInterfaceGetter(androidInterfaces)
	}
}

func androidInterfaces() ([]netmon.Interface, error) {
	fd, err := unix.Socket(unix.AF_NETLINK, unix.SOCK_RAW|unix.SOCK_CLOEXEC, unix.NETLINK_ROUTE)
	if err != nil {
		return nil, err
	}
	defer unix.Close(fd)
	req := make([]byte, 24)
	binary.NativeEndian.PutUint32(req[0:], 24)
	binary.NativeEndian.PutUint16(req[4:], unix.RTM_GETADDR)
	binary.NativeEndian.PutUint16(req[6:], unix.NLM_F_REQUEST|unix.NLM_F_DUMP)
	binary.NativeEndian.PutUint32(req[8:], 1)
	if err := unix.Sendto(fd, req, 0, &unix.SockaddrNetlink{Family: unix.AF_NETLINK}); err != nil {
		return nil, err
	}
	byIndex := map[int]*netmon.Interface{}
	buf := make([]byte, 1<<16)
	for {
		n, _, err := unix.Recvfrom(fd, buf, 0)
		if err != nil {
			return nil, err
		}
		msgs, err := syscall.ParseNetlinkMessage(buf[:n])
		if err != nil {
			return nil, err
		}
		for _, m := range msgs {
			switch m.Header.Type {
			case unix.NLMSG_DONE:
				return collect(byIndex), nil
			case unix.NLMSG_ERROR:
				return nil, syscall.Errno(-int32(binary.NativeEndian.Uint32(m.Data)))
			case unix.RTM_NEWADDR:
				addAddr(byIndex, m)
			}
		}
	}
}

func addAddr(byIndex map[int]*netmon.Interface, m syscall.NetlinkMessage) {
	if len(m.Data) < unix.SizeofIfAddrmsg {
		return
	}
	family, prefix := m.Data[0], int(m.Data[1])
	index := int(binary.NativeEndian.Uint32(m.Data[4:]))
	attrs, err := syscall.ParseNetlinkRouteAttr(&m)
	if err != nil {
		return
	}
	var ip net.IP
	var label string
	for _, a := range attrs {
		switch a.Attr.Type {
		case unix.IFA_LOCAL:
			ip = net.IP(a.Value)
		case unix.IFA_ADDRESS:
			if ip == nil {
				ip = net.IP(a.Value)
			}
		case unix.IFA_LABEL:
			label = string(a.Value[:len(a.Value)-1])
		}
	}
	if ip == nil {
		return
	}
	bits := 128
	if family == unix.AF_INET {
		bits = 32
	}
	iface := byIndex[index]
	if iface == nil {
		iface = &netmon.Interface{Interface: &net.Interface{
			Index: index,
			MTU:   1500,
			Flags: net.FlagUp | net.FlagRunning | net.FlagMulticast,
		}}
		byIndex[index] = iface
	}
	if label != "" {
		iface.Name = label
	}
	if ip.IsLoopback() {
		iface.Flags |= net.FlagLoopback
	}
	iface.AltAddrs = append(iface.AltAddrs, &net.IPNet{IP: ip, Mask: net.CIDRMask(prefix, bits)})
}

func collect(byIndex map[int]*netmon.Interface) []netmon.Interface {
	ret := make([]netmon.Interface, 0, len(byIndex))
	for _, iface := range byIndex {
		if iface.Name == "" {
			iface.Name = "if" + strconv.Itoa(iface.Index)
		}
		ret = append(ret, *iface)
	}
	sort.Slice(ret, func(i, j int) bool { return ret[i].Index < ret[j].Index })
	return ret
}
