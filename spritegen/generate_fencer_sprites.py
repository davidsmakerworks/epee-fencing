"""
generate_fencer_sprites.py
Generates pixel-art-style fencer sprite sheets for Epee Fencing (Godot 4.6).

Requires: Pillow (already installed in venv)
Output: spritegen/output/fencer_sheet.png
Frame size: 160 x 160 per pose
States (left to right): IDLE, EN_GARDE, ADVANCE, RETREAT, ATTACK, LUNGE, PARRY, RECOVER, HIT, BEAT_ATTACK
Rows (top to bottom): Blue team, Red team
"""

import os
import math
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
FRAME_W = 160
FRAME_H = 160
NUM_STATES = 10
NUM_TEAMS = 2

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "fencer_sheet.png")

# Team accent colors (same as game)
TEAM_BLUE = (51, 128, 230)     # ~Color(0.2, 0.5, 0.9)
TEAM_RED  = (230, 51, 51)      # ~Color(0.9, 0.2, 0.2)
TEAM_COLORS = [TEAM_BLUE, TEAM_RED]

# Base palette (close approximations of the game's `_draw()` colors)
WHITE       = (235, 235, 242)
LAME_GOLD   = (209, 191,  38)
BOOT_DARK   = ( 46,  46,  56)
MASK_GREY   = (179, 184, 191)
SKIN        = (209, 158, 133)
GLOVE       = (224, 224, 230)
BLADE       = (191, 199, 217)
BLADE_HILIGHT = (230, 235, 242)
BELL_GUARD  = (140, 148, 158)
EYE_DARK    = ( 38,  38,  51)
GRID_DARK   = ( 89,  89, 102)

# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------
def draw_rect(draw, x, y, w, h, color):
    """Draw a filled rectangle (x, y is top-left)."""
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def draw_line(draw, x1, y1, x2, y2, color, width=1):
    """Draw a line. Pillow draws with line center on coords, so we keep it simple."""
    draw.line([(x1, y1), (x2, y2)], fill=color, width=width)


def draw_circle(draw, cx, cy, r, color):
    """Draw a filled circle."""
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


# ---------------------------------------------------------------------------
# Body part helpers
# ---------------------------------------------------------------------------
FENCER_H = 100
BODY_W = 24
BLADE_L = 90

def draw_boots(draw, base_x, base_y, sway, color_mod=1.0):
    """Draw both boots."""
    bh, bw = 18, 10
    c = tuple(int(v * color_mod) for v in BOOT_DARK)
    draw_rect(draw, base_x - 8 + int(sway * 0.3), base_y + FENCER_H - bh - 5, bw, bh, c)
    draw_rect(draw, base_x + 4 + int(sway * 0.3), base_y + FENCER_H - bh - 5, bw, bh, c)


def draw_legs(draw, base_x, base_y, sway, color_mod=1.0):
    """Draw breeches / legs."""
    lh = 16
    c = tuple(int(v * color_mod) for v in WHITE)
    draw_rect(draw, base_x - 10 + int(sway * 0.4), base_y + FENCER_H - 18 - lh - 5, 12, lh, c)
    draw_rect(draw, base_x + 2 + int(sway * 0.4), base_y + FENCER_H - 18 - lh - 5, 12, lh, c)


def draw_torso(draw, base_x, base_y, sway, accent, color_mod=1.0):
    """Draw torso (lamé jacket)."""
    th = 34
    ty = base_y + FENCER_H - 18 - 16 - th - 5
    wc = tuple(int(v * color_mod) for v in WHITE)
    lc = tuple(int(v * color_mod) for v in LAME_GOLD)
    ac = tuple(int(v * color_mod) for v in accent)
    draw_rect(draw, base_x - BODY_W // 2 + int(sway), ty, BODY_W, th, wc)
    draw_rect(draw, base_x - int(BODY_W * 0.35) + int(sway), ty + 2, int(BODY_W * 0.7), th - 4, lc)
    draw_rect(draw, base_x - 2 + int(sway), ty, 4, th, ac)
    return ty  # torso top y


def draw_back_arm(draw, base_x, base_y, sway, facing, color_mod=1.0):
    """Draw back arm (guard position)."""
    torso_y = base_y + FENCER_H - 18 - 16 - 34 - 5
    bay = torso_y + 6
    wc = tuple(int(v * color_mod) for v in WHITE)
    gc = tuple(int(v * color_mod) for v in GLOVE)
    # upper arm
    sx = (base_x - BODY_W // 2 - 12) + int(sway)
    ex = (base_x - BODY_W // 2) + int(sway)
    draw_rect(draw, min(sx, ex), bay, abs(ex - sx) + 1, 5, wc)
    # glove
    gsx = (base_x - BODY_W // 2 - 16) + int(sway)
    gex = (base_x - BODY_W // 2 - 10) + int(sway)
    draw_rect(draw, min(gsx, gex), bay - 2, abs(gex - gsx) + 1, 9, gc)
    return bay


def draw_front_arm_and_blade(draw, base_x, base_y, sway, facing,
                              arm_extend, blade_angle, accent, color_mod=1.0):
    """Draw front arm, glove, blade, and bell guard."""
    torso_y = base_y + FENCER_H - 18 - 16 - 34 - 5
    blade_y_offset = 0  # simplified vs the is_player branch
    if facing < 0:
        blade_y_offset = 8
    else:
        blade_y_offset = -8

    fab_y = torso_y + 6 + blade_y_offset
    ext_px = arm_extend * 30.0
    shoulder_x = base_x + int(BODY_W * 0.3)
    upper_end_x = shoulder_x + int((8 + ext_px * 0.3))
    wc = tuple(int(v * color_mod) for v in WHITE)
    gc = tuple(int(v * color_mod) for v in GLOVE)

    # upper arm
    draw_rect(draw, min(shoulder_x, upper_end_x), fab_y, abs(upper_end_x - shoulder_x) + 1, 5, wc)
    # forearm
    forearm_end_x = upper_end_x + int(10 + ext_px * 0.7)
    draw_rect(draw, min(upper_end_x, forearm_end_x), fab_y - 1, abs(forearm_end_x - upper_end_x) + 1, 5, wc)
    # glove
    glove_x = forearm_end_x
    draw_rect(draw, glove_x, fab_y - 3, 8, 9, gc)

    # blade
    blade_base_x = glove_x + 8
    blade_base_y = fab_y
    # facing is 1 for right-facing sprites
    blade_end_x = int(blade_base_x + BLADE_L)
    blade_end_y = int(blade_base_y + blade_angle * 0.5)

    # blade steel tinted by accent
    blade_color = tuple(min(255, int(c * 0.85 + a * 0.15)) for c, a in zip(BLADE, accent))
    blade_color = tuple(int(v * color_mod) for v in blade_color)
    draw_line(draw, blade_base_x, blade_base_y, blade_end_x, blade_end_y, blade_color, 2)
    # highlight
    hl = tuple(int(v * color_mod) for v in BLADE_HILIGHT)
    draw_line(draw, blade_base_x, blade_base_y - 1, blade_end_x, blade_end_y - 1, hl, 1)

    # bell guard
    bc = tuple(int(v * color_mod) for v in BELL_GUARD)
    draw_circle(draw, blade_base_x, blade_base_y, 5, bc)

    return (blade_base_x, blade_base_y, blade_end_x, blade_end_y)


def draw_head(draw, base_x, base_y, sway, facing, accent, color_mod=1.0):
    """Draw mask and head."""
    torso_y = base_y + FENCER_H - 18 - 16 - 34 - 5
    head_y = torso_y - 18
    head_x = base_x + int(sway)
    mc = tuple(int(v * color_mod) for v in MASK_GREY)
    sc = tuple(int(v * color_mod) for v in SKIN)
    ec = tuple(int(v * color_mod) for v in EYE_DARK)
    gr = tuple(int(v * color_mod) for v in GRID_DARK)
    ac = tuple(int(v * color_mod) for v in accent)

    draw_rect(draw, head_x - 10, head_y - 14, 20, 22, mc)
    # mask grid vertical
    for mx in range(-8, 9, 3):
        draw_line(draw, mx + head_x, head_y - 12, mx + head_x, head_y + 6, gr, 1)
    # mask grid horizontal
    for my in range(-12, 7, 3):
        draw_line(draw, -8 + head_x, my + head_y, 8 + head_x, my + head_y, gr, 1)
    # face
    draw_rect(draw, head_x - 5, head_y - 8, 10, 10, sc)
    # eyes
    draw_rect(draw, head_x - 4, head_y - 5, 3, 2, ec)
    draw_rect(draw, head_x + 2, head_y - 5, 3, 2, ec)
    # crest
    draw_rect(draw, head_x - 11, head_y - 14, 22, 3, ac)


# ---------------------------------------------------------------------------
# Pose definitions
# ---------------------------------------------------------------------------
class Pose:
    def __init__(self, blade_angle=0.0, arm_extend=0.0, sway=0.0,
                 recoil_x=0, recoil_y=0, lunge_depth=0.0, color_mod=1.0):
        self.blade_angle = blade_angle
        self.arm_extend = arm_extend
        self.sway = sway
        self.recoil_x = recoil_x       # body shift
        self.recoil_y = recoil_y
        self.lunge_depth = lunge_depth # 0..1
        self.color_mod = color_mod


POSES = [
    # IDLE
    Pose(blade_angle=10.0, arm_extend=0.0, sway=0.0),
    # EN_GARDE
    Pose(blade_angle=-30.0, arm_extend=0.5, sway=0.0),
    # ADVANCE
    Pose(blade_angle=-20.0, arm_extend=0.4, sway=2.0),
    # RETREAT
    Pose(blade_angle=-35.0, arm_extend=0.3, sway=-2.0),
    # ATTACK
    Pose(blade_angle=-5.0, arm_extend=1.0, sway=3.0),
    # LUNGE
    Pose(blade_angle=0.0, arm_extend=1.0, sway=5.0, lunge_depth=1.0),
    # PARRY
    Pose(blade_angle=50.0, arm_extend=0.6, sway=0.0),
    # RECOVER
    Pose(blade_angle=-25.0, arm_extend=0.5, sway=0.0),
    # HIT
    Pose(blade_angle=30.0, arm_extend=0.2, sway=-5.0, recoil_x=-8, color_mod=0.85),
    # BEAT_ATTACK
    Pose(blade_angle=-15.0, arm_extend=0.7, sway=1.0),
]

STATE_NAMES = [
    "idle", "en_garde", "advance", "retreat", "attack",
    "lunge", "parry", "recover", "hit", "beat_attack"
]


def draw_fencer_to_frame(img, team_index, pose_index, facing=1):
    """Draw a single fencer frame into an existing PIL Image."""
    draw = ImageDraw.Draw(img)
    pose = POSES[pose_index]
    accent = TEAM_COLORS[team_index]
    cm = pose.color_mod

    base_x = img.width // 2 + pose.recoil_x
    base_y = img.height - FENCER_H - 20 + pose.recoil_y
    sway = pose.sway

    # Lunge: shift entire body forward, bend front knee visually
    if pose.lunge_depth > 0:
        base_x += int(20 * pose.lunge_depth)
        base_y += int(10 * pose.lunge_depth)

    draw_boots(draw, base_x, base_y, sway, cm)
    draw_legs(draw, base_x, base_y, sway, cm)
    torso_y = draw_torso(draw, base_x, base_y, sway, accent, cm)
    draw_back_arm(draw, base_x, base_y, sway, facing, cm)
    draw_front_arm_and_blade(draw, base_x, base_y, sway, facing,
                              pose.arm_extend, pose.blade_angle, accent, cm)
    draw_head(draw, base_x, base_y, sway, facing, accent, cm)

    # Parry arc indicator (green translucent arc) for PARRY state
    if STATE_NAMES[pose_index] == "parry":
        # Simplified: draw a green circle behind the blade
        draw.ellipse([
            base_x - 10 + int(sway), torso_y - 40,
            base_x + 60 + int(sway), torso_y + 10
        ], outline=(77, 255, 77), width=2)

    # Hit flash overlay (transparent red wash) for HIT state
    if STATE_NAMES[pose_index] == "hit":
        overlay = Image.new("RGBA", (img.width, img.height), (255, 77, 77, 40))
        img.paste(overlay, (0, 0), overlay)


# ---------------------------------------------------------------------------
# Main generation
# ---------------------------------------------------------------------------
def generate_sheet():
    sheet_w = FRAME_W * NUM_STATES
    sheet_h = FRAME_H * NUM_TEAMS
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    for team in range(NUM_TEAMS):
        for state in range(NUM_STATES):
            frame = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
            draw_fencer_to_frame(frame, team, state, facing=1)
            px = state * FRAME_W
            py = team * FRAME_H
            sheet.paste(frame, (px, py))

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    sheet.save(OUTPUT_PATH, "PNG")
    print(f"Fencer sprite sheet saved to: {OUTPUT_PATH}")
    print(f"  Sheet size: {sheet_w}x{sheet_h} pixels")
    print(f"  Frame size: {FRAME_W}x{FRAME_H} pixels")
    print(f"  States (left to right): {', '.join(STATE_NAMES)}")
    print(f"  Row 0 (top): Blue team | Row 1 (bottom): Red team")
    print(f"  Use in Godot: Import as AtlasTexture, slice by {FRAME_W}x{FRAME_H} cells")


if __name__ == "__main__":
    generate_sheet()
