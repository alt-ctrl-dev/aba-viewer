defmodule AbaViewerWeb.AbaLive.Index do
  use AbaViewerWeb, :live_view

  @max_file_size_bytes 10_485_760

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:avatar,
       accept: ~w(.aba),
       max_entries: 1,
       progress: &handle_progress/3,
       auto_upload: true,
     )|>assign( running: false, task: nil)}
       max_file_size: @max_file_size_bytes
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl Phoenix.LiveView
  def handle_info(:clear_success_flash, socket) do
    {:noreply, clear_flash(socket, :success)}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"

  defp format_bytes(bytes, kind \\ 0)

  defp format_bytes(bytes, kind) when is_integer(bytes) do
    bytes = div(bytes, 1024)
    #
    if bytes >= 1024 do
      format_bytes(bytes, kind + 1)
    else
      "#{bytes} #{byte_kind(kind)}"
    end
  end

  defp format_bytes(bytes, _) do
    "#{bytes} bytes"
  end

  defp byte_kind(0), do: "KB"
  defp byte_kind(1), do: "MB"
  defp byte_kind(2), do: "GB"
  defp byte_kind(_), do: "B"
  defp handle_progress(
         :avatar,
         %Phoenix.LiveView.UploadEntry{client_name: client_name, uuid: file_uuid} = entry,
         socket
       ) do
    if entry.done? do
      uploaded_file =
        consume_uploaded_entry(
          socket,
          entry,
          fn %{path: path} ->
            extension = Path.extname(client_name)

            dest =
              Path.join([
                :code.priv_dir(:aba_viewer),
                "static",
                "uploads",
                Enum.join([file_uuid, extension])
              ])

            File.cp!(path, dest)
            {:ok, "/uploads/#{Path.basename(dest)}"}
          end
        )

      Process.send_after(self(), :clear_success_flash, 5000)
      {:noreply, put_flash(socket, :success, "File uploaded! Processing now")|>assign( running: true, task: task)}
    else
      {:noreply, socket}
    end
  end
end
