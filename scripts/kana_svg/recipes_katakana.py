"""Draw recipes for the 46 base katakana.

Same approach as hiragana (tint the real glyph + a few simple shapes), but
katakana are angular - straight strokes and sharp corners - so props lean on
lines, arrowheads and dots. Associations from research_katakana.json (Tofugu).
"""

from __future__ import annotations

from .dsl import (Art, INK, RED, ORANGE, YELLOW, GREEN, TEAL, BLUE, INDIGO,
                  PINK, PURPLE, BROWN, WHITE, SKIN)
from .glyphs import Glyph
from .recipes_hiragana import body


# --- ア行 -------------------------------------------------------------------
def a(a_, g):  # antenne / A
    body(a_, g, INDIGO)
    a_.dot(60, 26, 2)                               # antenna tip
    a_.arc(60, 26, 6, -150, -30, color=INDIGO, w=1.2)   # signal wave
    a_.arc(60, 26, 9, -150, -30, color=INDIGO, w=1)


def i(a_, g):  # aigle / individu
    body(a_, g, BROWN)
    a_.dot(58, 34, 2)                               # eye
    a_.poly([(58, 36), (66, 38), (58, 40)], color=ORANGE, w=1.2, close=True, fill=ORANGE)  # beak


def u(a_, g):  # usine (fumée)
    body(a_, g, "#8892a0")
    a_.circle(60, 22, 2.4, fill="none", color="#8892a0", w=1.2)   # smoke puffs
    a_.circle(65, 16, 3.2, fill="none", color="#8892a0", w=1.2)


def e(a_, g):  # marche / poutre d'acier
    body(a_, g, "#7d8891")
    a_.dot(34, 34, 1.6)     # rivets
    a_.dot(66, 34, 1.6)
    a_.dot(34, 68, 1.6)
    a_.dot(66, 68, 1.6)


def o(a_, g):  # chanteur d'opéra
    body(a_, g, RED)
    a_.text(70, 30, "♪", size=10, color=INDIGO)   # music note


# --- カ行 -------------------------------------------------------------------
def ka(a_, g):  # katana
    body(a_, g, "#6b7683")
    a_.line(30, 30, 22, 22, color="#c0c8d0", w=1.4)   # slash motion
    a_.line(36, 26, 30, 18, color="#c0c8d0", w=1.2)


def ki(a_, g):  # clé
    body(a_, g, "#d09a3e")
    a_.circle(48, 70, 5, fill=WHITE, color="#8a5a1e", w=1.8)   # key ring at the stem end


def ku(a_, g):  # chapeau de cuisinier / bec
    body(a_, g, ORANGE)
    a_.dot(52, 42, 2)   # eye by the open beak


def ke(a_, g):  # képi
    body(a_, g, INDIGO)
    a_.circle(46, 30, 2.6, fill=YELLOW, color=INK, w=1)   # cap badge


def ko(a_, g):  # coffre ouvert
    body(a_, g, BROWN)
    a_.circle(52, 48, 3.2, fill=YELLOW, color=INK, w=1)   # coin inside the chest


# --- サ行 -------------------------------------------------------------------
def sa(a_, g):  # sardine embrochée
    body(a_, g, "#7fb5c7")
    a_.dot(40, 30, 2)   # fish eye
    a_.poly([(30, 40), (22, 34), (24, 46)], color="#7fb5c7", w=1.2, close=True, fill="#7fb5c7")  # tail


def shi(a_, g):  # smiley clin d'œil
    body(a_, g, YELLOW)
    a_.cheeks(50, 54, gap=40, rx=3, ry=2)   # blushing wink


def su(a_, g):  # costume de super-héros
    body(a_, g, BLUE)
    a_.text(46, 52, "S", size=9, color=YELLOW)   # chest emblem


def se(a_, g):  # serpent dressé
    body(a_, g, GREEN)
    a_.dot(60, 34, 2)                            # snake eye
    a_.line(66, 32, 74, 30, color=RED, w=1.4)    # forked tongue


def so(a_, g):  # tremplin de saut à ski
    body(a_, g, TEAL)
    a_.dot(58, 30, 2.4, color=RED)   # ski jumper flying off
    a_.line(60, 28, 68, 24, color=RED, w=1.2)


# --- タ行 -------------------------------------------------------------------
def ta(a_, g):  # taco
    body(a_, g, "#e0a53a")
    a_.line(40, 50, 52, 50, color=GREEN, w=1.8)   # filling
    a_.line(40, 58, 52, 58, color=RED, w=1.8)


def chi(a_, g):  # chimpanzé bras levés / cheerleader
    body(a_, g, ORANGE)
    a_.circle(34, 32, 3, fill=RED, color=INK, w=1)     # pom-poms at the raised arms
    a_.circle(70, 30, 3, fill=RED, color=INK, w=1)


def tsu(a_, g):  # tsunami (éclaboussures)
    body(a_, g, BLUE)
    a_.dot(38, 30, 1.6, color=WHITE)   # spray droplets
    a_.dot(54, 30, 1.6, color=WHITE)
    a_.dot(46, 24, 1.4, color=WHITE)


def te(a_, g):  # poteau télégraphique
    body(a_, g, "#7d8891")
    a_.dot(60, 34, 2, color=INK)   # a bird on the wire


def to(a_, g):  # totem
    body(a_, g, BROWN)
    a_.eyes(46, 40, gap=7, r=1.9)


# --- ナ行 -------------------------------------------------------------------
def na(a_, g):  # narval
    body(a_, g, TEAL)
    a_.path("M20 76Q26 72 32 76T44 76", color=BLUE, w=1.4)   # water surface
    a_.dot(40, 44, 1.8)   # eye at the base of the tusk


def ni(a_, g):  # nid (deux brindilles)
    body(a_, g, BROWN)
    a_.circle(58, 48, 3, fill=WHITE, color=INK, w=1)   # egg between the twigs


def nu(a_, g):  # nouilles aux baguettes
    body(a_, g, "#e9c46a")
    a_.line(40, 22, 66, 30, color=BROWN, w=1.8)   # chopstick
    a_.line(46, 20, 60, 34, color=BROWN, w=1.8)


def ne(a_, g):  # skieur dans la neige
    body(a_, g, INDIGO)
    a_.sparkle(70, 26, 2.4, color=WHITE)   # snow flurry
    a_.dot(24, 30, 1.4, color=WHITE)


def no(a_, g):  # aiguille qui pointe le Nord
    body(a_, g, RED)
    a_.poly([(58, 30), (54, 22), (64, 26)], color=RED, w=1, close=True, fill=RED)  # arrowhead N
    a_.text(70, 24, "N", size=8, color=INK)


# --- ハ行 -------------------------------------------------------------------
def ha(a_, g):  # chapeau conique / ha-ha
    body(a_, g, "#c98a5a")
    a_.dot(50, 30, 2.2, color=RED)   # hat top knob
    a_.eyes(50, 56, gap=20, r=2.4)   # laughing eyes under the brim


def hi(a_, g):  # visage qui glousse
    body(a_, g, YELLOW)
    a_.dot(40, 42, 2.2)   # eye of the grinning profile


def fu(a_, g):  # drapeau / fumée
    body(a_, g, "#8892a0")
    a_.arc(66, 30, 4, 120, 260, color="#8892a0", w=1.2)   # curl of smoke


def he(a_, g):  # montagne
    body(a_, g, GREEN)
    a_.poly([(42, 44), (50, 34), (58, 44)], color=WHITE, w=1.4)   # snowy peak


def ho(a_, g):  # croix rayonnante
    body(a_, g, RED)
    a_.sparkle(50, 26, 3.2, color=YELLOW)   # holy light


# --- マ行 -------------------------------------------------------------------
def ma(a_, g):  # marteau
    body(a_, g, "#7d8891")
    a_.line(52, 70, 52, 82, color=BROWN, w=1.6)   # a nail being struck
    a_.poly([(48, 82), (56, 82), (52, 88)], color="#555", w=1, close=True, fill="#888")


def mi(a_, g):  # trois missiles
    body(a_, g, "#7d8891")
    for yy in (34, 50, 66):   # arrowheads flying right
        a_.poly([(74, yy - 3), (82, yy), (74, yy + 3)], color=RED, w=1, close=True, fill=RED)


def mu(a_, g):  # museau de vache
    body(a_, g, "#c98a5a")
    a_.dot(44, 58, 1.8)   # nostrils
    a_.dot(56, 58, 1.8)


def me(a_, g):  # ciseaux
    body(a_, g, "#8892a0")
    a_.circle(34, 70, 3.5, fill="none", color=INK, w=1.6)   # finger holes
    a_.circle(66, 70, 3.5, fill="none", color=INK, w=1.6)


def mo(a_, g):  # panneau (mot)
    body(a_, g, GREEN)
    a_.text(50, 26, "abc", size=6, color=WHITE)   # word on the sign


# --- ヤ行 -------------------------------------------------------------------
def ya(a_, g):  # yacht
    body(a_, g, INDIGO)
    a_.path("M14 78Q26 74 38 78T62 78T86 78", color=BLUE, w=1.4)   # sea


def yu(a_, g):  # tuyau coudé
    body(a_, g, "#7d8891")
    a_.rect(40, 24, 6, 4, r=1, fill="none", color=INK, sw=1)   # pipe flange
    a_.rect(72, 64, 4, 6, r=1, fill="none", color=INK, sw=1)


def yo(a_, g):  # yogi
    body(a_, g, PURPLE)
    a_.circle(30, 28, 4, fill=SKIN, color=INK, w=1)   # yogi's head


# --- ラ行 -------------------------------------------------------------------
def ra(a_, g):  # rat à lunettes
    body(a_, g, "#9aa0a6")
    a_.line(36, 34, 64, 34, color=INK, w=2.2)          # sunglasses bar
    a_.circle(44, 34, 2.6, fill=INK)
    a_.circle(58, 34, 2.6, fill=INK)


def ri(a_, g):  # rideau à deux pans
    body(a_, g, TEAL)
    a_.line(30, 26, 74, 26, color=BROWN, w=2)          # curtain rod
    a_.circle(52, 26, 2, fill="none", color=BROWN, w=1)


def ru(a_, g):  # rue qui bifurque
    body(a_, g, "#7d8891")
    a_.line(40, 66, 30, 74, color=YELLOW, w=1.2, dash="2 2")   # lane markings
    a_.line(60, 60, 74, 52, color=YELLOW, w=1.2, dash="2 2")


def re(a_, g):  # renard bondissant
    body(a_, g, ORANGE)
    a_.dot(70, 30, 1.8)   # fox eye near the leaping tip
    a_.poly([(72, 30), (80, 28), (74, 34)], color=ORANGE, w=1, close=True, fill=ORANGE)  # ear


def ro(a_, g):  # tête de robot
    body(a_, g, "#8892a0")
    a_.eyes(50, 45, gap=16, r=3)
    a_.line(50, 24, 50, 16, color=INK, w=1.4)   # antenna
    a_.dot(50, 15, 1.8, color=RED)


# --- ワ行 -------------------------------------------------------------------
def wa(a_, g):  # bouche grande ouverte
    body(a_, g, RED)
    a_.ellipse(52, 58, 6, 4, fill="#7a1f1f", color=INK, w=1)   # open mouth cavity
    a_.arc(52, 60, 5, 20, 160, color=PINK, w=1.4)             # tongue


def wo(a_, g):  # chien qui aboie, langue tirée
    body(a_, g, BROWN)
    a_.dot(40, 34, 1.8)   # eye
    a_.path("M60 66Q64 76 70 72", color=RED, w=2.4)   # lolling tongue


def n(a_, g):  # clin d'œil
    body(a_, g, INDIGO)
    a_.arc(40, 34, 4, 200, 340, color=INK, w=1.4)   # the single winking eye


REGISTRY = {
    "ア": a, "イ": i, "ウ": u, "エ": e, "オ": o,
    "カ": ka, "キ": ki, "ク": ku, "ケ": ke, "コ": ko,
    "サ": sa, "シ": shi, "ス": su, "セ": se, "ソ": so,
    "タ": ta, "チ": chi, "ツ": tsu, "テ": te, "ト": to,
    "ナ": na, "ニ": ni, "ヌ": nu, "ネ": ne, "ノ": no,
    "ハ": ha, "ヒ": hi, "フ": fu, "ヘ": he, "ホ": ho,
    "マ": ma, "ミ": mi, "ム": mu, "メ": me, "モ": mo,
    "ヤ": ya, "ユ": yu, "ヨ": yo,
    "ラ": ra, "リ": ri, "ル": ru, "レ": re, "ロ": ro,
    "ワ": wa, "ヲ": wo, "ン": n,
}
