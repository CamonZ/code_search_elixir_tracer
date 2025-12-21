defmodule ComprehensiveStructTest do
  @moduledoc """
  Comprehensive test for struct handling in different contexts.
  """

  defstruct [:name, :value, :count]

  alias ExAst.Extractor.Stats

  # ====================================================================
  # 1. Struct creation (should NOT be extracted as calls)
  # ====================================================================

  def create_struct do
    %ComprehensiveStructTest{name: "test", value: 42}
  end

  # ====================================================================
  # 2. Pattern matching in function heads (should NOT be extracted as calls)
  # ====================================================================

  def match_struct(%ComprehensiveStructTest{name: name}) do
    String.upcase(name)
  end

  def match_aliased_struct(%Stats{total_calls: count}) do
    count + 1
  end

  # ====================================================================
  # 3. Struct updates (should NOT be extracted as calls)
  # ====================================================================

  def update_struct(s) do
    %ComprehensiveStructTest{s | name: "updated"}
  end

  # ====================================================================
  # 4. Typespecs with struct types (should be in specs output)
  # ====================================================================

  @spec process_struct(%ComprehensiveStructTest{}) :: String.t()
  def process_struct(%ComprehensiveStructTest{name: name}) do
    name
  end

  @spec create_with_stats(%Stats{}) :: %ComprehensiveStructTest{}
  def create_with_stats(%Stats{total_calls: count}) do
    %ComprehensiveStructTest{count: count}
  end

  # ====================================================================
  # 5. Real function calls (SHOULD be extracted)
  # ====================================================================

  def with_real_calls(text) do
    # These should be extracted as calls
    uppercased = String.upcase(text)
    trimmed = String.trim(uppercased)
    helper_function(trimmed)
  end

  defp helper_function(x) do
    x
  end
end
