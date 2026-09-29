import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from site_parsers.common import parse_document, plain_text, rich_text, ruby_pairs


def test_ruby_annotation_does_not_swallow_following_base_text():
    tree = parse_document('<p><ruby>食<rt>た</rt>べる</ruby>。</p>')
    assert plain_text(tree) == '食べる。'
    assert ruby_pairs(tree) == [{'base': '食べる', 'reading': 'た'}]


def test_skipped_nodes_keep_sentence_tail_and_exclude_comment_body():
    tree = parse_document('<p>One<script>bad()</script> two<!-- private --> three.</p>')
    assert plain_text(tree) == 'One two three.'


def test_subtree_does_not_leak_following_field_and_preserves_educational_spacing():
    tree = parse_document('<div><span>わたし は</span> NEXT FIELD</div>')
    assert plain_text(tree[0]) == 'わたし は'


def test_annotations_still_point_to_their_text_after_tail_recovery():
    tree = parse_document('<p>A<script>x</script> <mark title="Reading">kai</mark> kai.</p>')
    result = rich_text(tree)
    assert result.text == 'A kai kai.'
    assert result.spans[0].start == 2
    assert result.text[result.spans[0].start:result.spans[0].end] == 'kai'
