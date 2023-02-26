defmodule Flop.CustomTypes.AnyTest do
  use ExUnit.Case, async: true
  alias Flop.CustomTypes.Any

  describe "type/0" do
    test "returns :string" do
      assert Any.type() == :string
    end
  end

  describe "cast/1" do
    test "casts any value" do
      assert Any.cast(1) == {:ok, 1}
      assert Any.cast(1.2) == {:ok, 1.2}
      assert Any.cast(nil) == {:ok, nil}
      assert Any.cast(true) == {:ok, true}
      assert Any.cast("a") == {:ok, "a"}
    end
  end

  describe "dump/1" do
    test "returns strings" do
      assert Any.dump(1) == {:ok, "1"}
      assert Any.dump(1.2) == {:ok, "1.2"}
      assert Any.dump(nil) == {:ok, ""}
      assert Any.dump(true) == {:ok, "true"}
      assert Any.dump("a") == {:ok, "a"}
    end
  end
end
