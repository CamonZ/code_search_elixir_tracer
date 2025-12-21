defmodule CollisionModuleA do
  @moduledoc """
  Test fixture for function key collision bug.
  Has first_function/0 at line 6, same as CollisionModuleB.
  """

  def first_function do
    :module_a_result
  end

  def second_function(arg) do
    {:module_a, arg}
  end
end
