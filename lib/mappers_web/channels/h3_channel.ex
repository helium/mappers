defmodule MappersWeb.H3Channel do
  use Phoenix.Channel

  def join("h3:new", _message, socket) do
    {:ok, socket}
  end
end
