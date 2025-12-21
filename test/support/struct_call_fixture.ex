defmodule StructCallFixture do
  @moduledoc """
  Test fixture to verify that struct creation is not extracted as a function call.
  """

  defstruct [:name]

  alias ExAst.Extractor.Stats

  def create_local_struct do
    %StructCallFixture{name: "test"}
  end

  def create_aliased_struct do
    %Stats{}
  end

  def create_full_module_struct do
    %ExAst.Extractor.Stats{total_calls: 0}
  end
end
