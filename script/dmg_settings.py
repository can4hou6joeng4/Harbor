import os
import shutil

application = os.path.abspath(defines["app"])  # noqa: F821
background_path = os.path.abspath(defines["background"])  # noqa: F821
retina_background_path = os.path.splitext(background_path)[0] + "@2x" + os.path.splitext(background_path)[1]
app_name = os.path.basename(application)

format = "UDZO"
filesystem = "HFS+"
files = [(application, app_name)]
symlinks = {"Applications": "/Applications"}

window_rect = ((200, 160), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0

show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
hide = [".background.tiff"]
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 128
background = background_path
icon_locations = {
    app_name: (165, 205),
    "Applications": (495, 205),
}


def create_hook(mount_point, _options):
    background_dir = os.path.join(mount_point, ".background")
    os.makedirs(background_dir, exist_ok=True)
    shutil.copyfile(background_path, os.path.join(background_dir, "dmg-background.png"))
    if os.path.isfile(retina_background_path):
        shutil.copyfile(retina_background_path, os.path.join(background_dir, "dmg-background@2x.png"))
