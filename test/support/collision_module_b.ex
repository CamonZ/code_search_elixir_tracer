defmodule CollisionModuleB do
  @moduledoc """
  Test fixture for function key collision bug.
  Has first_function/0 at line 6, same as CollisionModuleA.
  """

  def first_function do
    :module_b_result
  end

  def second_function(arg) do
    {:module_b, arg}
  end
end
