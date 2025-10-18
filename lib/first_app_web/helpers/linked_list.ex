defmodule FirstAppWeb.LinkedList do
  @moduledoc "Simple linked list for game events"

  defstruct [:type, :data, :next]

  def new(type, data) do
    %__MODULE__{type: type, data: data, next: nil}
  end

  def prepend(nil, type, data) do
    new(type, data)
  end

  def prepend(%__MODULE__{} = list, type, data) do
    %__MODULE__{type: type, data: data, next: list}
  end

  def to_list(nil), do: []
  def to_list(%__MODULE__{type: t, data: d, next: n}), do: [{t, d} | to_list(n)]
end
