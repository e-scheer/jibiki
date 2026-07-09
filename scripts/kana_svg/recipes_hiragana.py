"""Draw recipes for the 46 base hiragana.

Each recipe tints the *real* glyph outline as the body of its mnemonic object
(so the character is always accurate and legible) and adds a few simple shapes on
top, positioned against the coordinate grid (see `_qa_ref.py`). Associations come
from research_hiragana.json (Tofugu-derived). Keep every drawing simple.
"""

from __future__ import annotations

from .dsl import (Art, INK, RED, ORANGE, YELLOW, GREEN, TEAL, BLUE, INDIGO,
                  PINK, PURPLE, BROWN, WHITE, SKIN)
from .glyphs import Glyph


def body(a: Art, g: Glyph, fill: str, line: str = INK, w: float = 0.7) -> None:
    """Paint the glyph as the object body: colour fill + thin dark outline."""
    a.glyph(g, fill=fill)
    a.glyph(g, stroke=line, w=w)


# --- あ行 -------------------------------------------------------------------
def a(a_, g):  # âne - un A majuscule / une tête d'âne
    body(a_, g, "#b9b0a4")
    a_.ellipse(41, 15, 3, 7, fill="#b9b0a4", color=INK, w=0.7, rotate=-14)  # ears
    a_.ellipse(60, 15, 3, 7, fill="#b9b0a4", color=INK, w=0.7, rotate=14)
    a_.eyes(52, 40, gap=11, r=2.6)


def i(a_, g):  # deux skis
    body(a_, g, BLUE)
    a_.line(24, 70, 44, 74, color=RED, w=2.4)   # ski tips
    a_.line(56, 66, 76, 70, color=RED, w=2.4)


def u(a_, g):  # hibou
    body(a_, g, BROWN)
    a_.eyes(50, 46, gap=13, r=4.2)


def e(a_, g):  # émeu (oiseau à crête)
    body(a_, g, TEAL)
    a_.line(44, 26, 40, 15, color=INK, w=1.8)   # crest
    a_.line(48, 25, 46, 14, color=INK, w=1.8)
    a_.dot(46, 33, 1.8)                           # eye


def o(a_, g):  # Oh! (boule lancée)
    body(a_, g, RED)
    a_.circle(70, 28, 4.5, fill=WHITE, color=INK, w=1.4)  # the flying ball (detached stroke)
    a_.sparkle(80, 20, 3)


# --- か行 -------------------------------------------------------------------
def ka(a_, g):  # karatéka (moustique 'ka')
    body(a_, g, PURPLE)
    a_.eyes(40, 40, gap=9, r=2.6)


def ki(a_, g):  # clé
    body(a_, g, "#d09a3e")
    a_.circle(45, 66, 6, fill=WHITE, color="#8a5a1e", w=1.8)  # key ring
    a_.sparkle(72, 22, 3)


def ku(a_, g):  # bec (coucou)
    body(a_, g, ORANGE)
    a_.dot(52, 40, 2.2)  # eye above the open beak


def ke(a_, g):  # algue / queue qui ondule
    body(a_, g, GREEN)


def ko(a_, g):  # deux cordes
    body(a_, g, BROWN)


# --- さ行 -------------------------------------------------------------------
def sa(a_, g):  # salade qu'on remue
    body(a_, g, GREEN)
    a_.line(58, 24, 66, 14, color=BROWN, w=2.6)  # spoon handle


def shi(a_, g):  # chignon / mèche
    body(a_, g, PINK)
    a_.circle(44, 34, 5, fill="none", color=PURPLE, w=2)  # the bun


def su(a_, g):  # sucette
    body(a_, g, RED)
    a_.circle(46, 60, 3.2, fill="none", color=WHITE, w=1.4)  # spiral centre of the lolly


def se(a_, g):  # serpent dressé
    body(a_, g, GREEN)
    a_.dot(64, 34, 2)      # snake head eye
    a_.line(66, 34, 74, 32, color=RED, w=1.4)  # tongue


def so(a_, g):  # soufflet / accordéon
    body(a_, g, INDIGO)


# --- た行 -------------------------------------------------------------------
def ta(a_, g):  # taco
    body(a_, g, "#e0a53a")
    a_.line(60, 46, 72, 46, color=GREEN, w=2)   # filling
    a_.line(60, 54, 72, 54, color=RED, w=2)


def chi(a_, g):  # chiffre 5 / sourire 'cheese'
    body(a_, g, ORANGE)
    a_.eyes(50, 34, gap=10, r=2.4)


def tsu(a_, g):  # vague de tsunami
    body(a_, g, BLUE)
    a_.path("M28 40Q32 34 38 40", color=WHITE, w=1.6)  # foam
    a_.path("M44 40Q48 34 54 40", color=WHITE, w=1.6)


def te(a_, g):  # télescope / main
    body(a_, g, INDIGO)
    a_.circle(50, 66, 4.5, fill="none", color=YELLOW, w=1.8)  # lens


def to(a_, g):  # totem
    body(a_, g, BROWN)
    a_.eyes(46, 40, gap=7, r=2)


# --- な行 -------------------------------------------------------------------
def na(a_, g):  # nageur
    body(a_, g, TEAL)
    a_.path("M20 74Q26 70 32 74T44 74", color=BLUE, w=1.6)  # water ripples


def ni(a_, g):  # nid
    body(a_, g, BROWN)
    a_.circle(64, 34, 2.4, fill=WHITE, color=INK, w=1)   # egg
    a_.circle(70, 36, 2.4, fill=WHITE, color=INK, w=1)


def nu(a_, g):  # nouilles
    body(a_, g, "#e9c46a")
    a_.circle(62, 54, 8, fill="none", color=BROWN, w=1.6)   # noodle swirl
    a_.circle(62, 54, 3.5, fill="none", color=BROWN, w=1.4)


def ne(a_, g):  # nœud (ruban)
    body(a_, g, PINK)
    a_.circle(62, 58, 5, fill="none", color=RED, w=1.8)  # ribbon loop


def no(a_, g):  # nombril / spirale interdit
    body(a_, g, RED)
    a_.circle(50, 50, 4, fill="none", color=WHITE, w=1.6)  # inner swirl


# --- は行 -------------------------------------------------------------------
def ha(a_, g):  # hache
    body(a_, g, "#c0785a")
    a_.line(28, 26, 28, 74, color="#5a3a28", w=2)  # emphasise handle


def hi(a_, g):  # grand sourire (hi hi !)
    body(a_, g, YELLOW)
    a_.eyes(44, 40, gap=12, r=3)   # laughing face; the glyph curve is the grin


def fu(a_, g):  # fou (bouffon) qui danse
    body(a_, g, PURPLE)
    a_.circle(46, 26, 3.2, fill=SKIN, color=INK, w=1)  # head


def he(a_, g):  # montagne
    body(a_, g, GREEN)
    a_.poly([(40, 44), (48, 34), (56, 44)], color=WHITE, w=1.6)  # snowy peak


def ho(a_, g):  # Père Noël (Ho ho ho !)
    body(a_, g, RED)
    a_.circle(62, 30, 3, fill=WHITE, color=INK, w=1)  # pompom on the extra bar


# --- ま行 -------------------------------------------------------------------
def ma(a_, g):  # maman (chignon)
    body(a_, g, PINK)
    a_.circle(50, 26, 4, fill=BROWN, color=INK, w=1)  # hair bun
    a_.eyes(50, 42, gap=10, r=2.2)


def mi(a_, g):  # note MI / 21
    body(a_, g, PURPLE)
    a_.line(58, 26, 66, 20, color=INK, w=2)  # musical note flag


def mu(a_, g):  # vache (Meuh !)
    body(a_, g, "#c98a5a")
    a_.line(70, 30, 76, 22, color=INK, w=2)  # horn (detached stroke)
    a_.eyes(40, 42, gap=9, r=2.6)


def me(a_, g):  # mètre ruban / œil
    body(a_, g, TEAL)
    a_.circle(52, 56, 3.5, fill=WHITE, color=INK, w=1.4)  # tape hub / pupil


def mo(a_, g):  # hameçon où ça mord
    body(a_, g, BLUE)
    a_.path("M40 66Q34 70 40 74", color=INK, w=1.6)  # hook barb


# --- や行 -------------------------------------------------------------------
def ya(a_, g):  # yak / yacht
    body(a_, g, "#8d6346")
    a_.line(66, 34, 74, 28, color=INK, w=2)  # horn/mast tip on the dot stroke


def yu(a_, g):  # poisson embroché
    body(a_, g, ORANGE)
    a_.dot(40, 48, 2)   # fish eye inside the loop
    a_.poly([(58, 52), (66, 46), (66, 58)], color=ORANGE, w=1.4, close=True, fill=ORANGE)  # tail fin


def yo(a_, g):  # yoyo
    body(a_, g, RED)
    a_.circle(50, 62, 5, fill="none", color=WHITE, w=1.6)  # yoyo hub


def ra(a_, g):  # rat / lapin assis
    body(a_, g, "#9aa0a6")
    a_.ellipse(56, 22, 2.4, 6, fill="#9aa0a6", color=INK, w=0.7, rotate=10)  # ear on top stroke
    a_.dot(50, 50, 2)   # eye


# --- ら行 continued ---------------------------------------------------------
def ri(a_, g):  # roseaux / brins de riz
    body(a_, g, GREEN)
    a_.line(38, 30, 36, 20, color=GREEN, w=1.8)  # reed tips
    a_.line(64, 28, 66, 18, color=GREEN, w=1.8)


def ru(a_, g):  # rue finissant en rond-point
    body(a_, g, "#7d8891")
    a_.circle(56, 62, 3, fill="none", color=YELLOW, w=1.6)  # roundabout centre


def re(a_, g):  # réverbère
    body(a_, g, INDIGO)
    a_.circle(62, 34, 4, fill=YELLOW, color=INK, w=1)  # lamp glow


def ro(a_, g):  # route ouverte (serpente)
    body(a_, g, "#7d8891")
    a_.line(40, 40, 60, 40, color=YELLOW, w=1.4, dash="3 3")  # road markings


# --- わ行 -------------------------------------------------------------------
def wa(a_, g):  # wagon (roue)
    body(a_, g, RED)
    a_.circle(60, 60, 5, fill="none", color=INK, w=1.6)  # wheel
    a_.dot(60, 60, 1.4)


def wo(a_, g):  # 'Woo !' (boomerang)
    body(a_, g, PURPLE)
    a_.path("M64 66Q74 62 70 54", color=BROWN, w=2)  # boomerang arc


def n(a_, g):  # 'n' cursif
    body(a_, g, INDIGO)
    a_.text(72, 40, "n", size=12, color=INDIGO)


REGISTRY = {
    "あ": a, "い": i, "う": u, "え": e, "お": o,
    "か": ka, "き": ki, "く": ku, "け": ke, "こ": ko,
    "さ": sa, "し": shi, "す": su, "せ": se, "そ": so,
    "た": ta, "ち": chi, "つ": tsu, "て": te, "と": to,
    "な": na, "に": ni, "ぬ": nu, "ね": ne, "の": no,
    "は": ha, "ひ": hi, "ふ": fu, "へ": he, "ほ": ho,
    "ま": ma, "み": mi, "む": mu, "め": me, "も": mo,
    "や": ya, "ゆ": yu, "よ": yo,
    "ら": ra, "り": ri, "る": ru, "れ": re, "ろ": ro,
    "わ": wa, "を": wo, "ん": n,
}
