import os
import sys

import theme_engine

theme, template, target = sys.argv[1:4]
os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
tokens = theme_engine.load_theme(theme)
rendered = theme_engine.render(open(template).read(), tokens)
open(target, "w").write(rendered)
