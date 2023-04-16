defmodule AbaViewerWeb.AbaLive.Index do
  use AbaViewerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end


  # @impl true
  # def handle_info({AbaViewerWeb.AbaLive.FormComponent, {:saved, aba}}, socket) do
  #   {:noreply, socket}
  # end

end
