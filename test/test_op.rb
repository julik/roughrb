# frozen_string_literal: true

require_relative "test_helper"
require "rough/op"

class TestOp < Minitest::Test
  def test_op_struct
    op = Rough::Op.new(op: :move, data: [10, 20])
    assert_equal :move, op.op
    assert_equal [10, 20], op.data
  end

  def test_opset_struct
    ops = [Rough::Op.new(op: :move, data: [0, 0])]
    opset = Rough::OpSet.new(type: :path, ops: ops)
    assert_equal :path, opset.type
    assert_equal 1, opset.ops.length
    assert_nil opset.size
  end

  def test_drawable_struct
    drawable = Rough::Drawable.new(shape: "line", options: nil, sets: [])
    assert_equal "line", drawable.shape
    assert_equal [], drawable.sets
  end

  def test_path_info_struct
    pi = Rough::PathInfo.new(d: "M0 0L10 10", stroke: "#000", stroke_width: 1)
    assert_equal "M0 0L10 10", pi.d
    assert_nil pi.fill
  end
end
