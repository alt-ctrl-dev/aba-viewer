defmodule AbaViewerWeb.AbaLive.Index do
  use AbaViewerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:avatar,
       accept: ~w(.jpg),
       max_entries: 1,
       progress: &handle_progress/3,
       auto_upload: true
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"

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

      {:noreply, put_flash(socket, :info, "file #{uploaded_file} uploaded")}
    else
      {:noreply, socket}
    end
  end
end
