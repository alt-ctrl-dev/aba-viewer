defmodule AbaViewerWeb.AbaLive.Index do
  use AbaViewerWeb, :live_view

  @max_file_size_bytes 2_097_152

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:avatar,
       accept: ~w(.aba),
       max_entries: 1,
       progress: &handle_progress/3,
       auto_upload: true,
       max_file_size: @max_file_size_bytes
     )
     |> assign(
       running: false,
       task: nil,
       result: nil,
       error: nil,
       max_file_size_bytes: @max_file_size_bytes
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket |> assign(result: nil, error: nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl Phoenix.LiveView
  def handle_info({ref, result}, socket) when socket.assigns.task.ref == ref do
    Process.demonitor(ref, [:flush])

    socket =
      case result do
        {:error, :incorrect_order_detected} ->
          assign(socket, error: "Incorrect order was detected in the file")

        {:error, :multiple_description_records, [line: line]} ->
          assign(socket, error: "Multiple description records found. See line #{line}")

        {:error, :multiple_file_total_records, [line: line]} ->
          assign(socket, error: "Multiple file records found. See line #{line}")

        output ->
          output = Enum.filter(output, fn error -> elem(error, 1) == :error end)
          assign(socket, result: output)
      end
      |> assign(running: false)

    {:noreply, clear_flash(socket, :success)}
  end

  @impl Phoenix.LiveView
  def handle_info(:clear_success_flash, socket) do
    {:noreply, clear_flash(socket, :success)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:incorrect_length), do: "Incorrect length"

  defp error_to_string({:invalid_format, issues}),
    do: Enum.map_join(issues, ", ", fn issue -> issue_error(issue) end)

  defp error_to_string(x), do: "Unknown error #{inspect(x)}"

  defp format_bytes(bytes, kind \\ 0)

  defp format_bytes(bytes, kind) when is_integer(bytes) do
    bytes = div(bytes, 1024)

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

  defp issue_error(:bsb_filler), do: "Incorrect BSB filler"
  defp issue_error(:records_mismatch), do: "Records count don't match"
  defp issue_error(:bsb), do: "Incorrect BSB"
  defp issue_error(:account_number), do: "Incorrect Account Number"
  defp issue_error(x), do: x

  defp handle_progress(
         :avatar,
         %Phoenix.LiveView.UploadEntry{client_name: client_name, uuid: file_uuid} = entry,
         socket
       ) do
    if entry.done? do
      task =
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

            task = create_task(dest)

            {:ok, task}
          end
        )

      Process.send_after(self(), :clear_success_flash, 5000)

      {:noreply,
       put_flash(socket, :success, "File uploaded! Processing now")
       |> assign(running: true, task: task, result: nil, error: nil)}
    else
      {:noreply, socket}
    end
  end

  # """
  # Creates a task to read the ABA file and get the results. It deletes the file after processing it
  # """
  defp create_task(dest) do
    Task.async(fn ->
      result = AbaValidator.process_aba_file(dest)
      File.rm!(dest)
      result
    end)
  end

  def record(%{item: {:descriptive_record, :error, result}} = assigns) do
    assigns = assign_new(assigns, :error, fn -> result end)

    ~H"""
    <div class="p-4 mb-4 text-sm text-red-800 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400" role="alert">
      <div class="flex space-x-4">
        <Heroicons.exclamation_circle class="w-6 h-6 text-red-900 fill-red-200" />
        <p>Descriptive record has the following issue(s): <%= error_to_string(@error) %></p>
      </div>
    </div>
    """
  end

  def record(%{item: {:descriptive_record, :ok, result}} = assigns) do
    assigns = assign_new(assigns, :result, fn -> result end)

    ~H"""

    <div class="p-4 mb-4 text-sm text-emerald-800 rounded-lg bg-emerald-50 dark:bg-gray-800 dark:text-emerald-400" role="alert">
    <div class="flex space-x-4">
      <Heroicons.check_circle class="w-6 h-6 text-green-900 fill-green-200" />
      <p>Descriptive record is good</p>
    </div>
    </div>
    """
  end

  def record(%{item: {:file_total_record, :error, result}} = assigns) do
    assigns = assign_new(assigns, :error, fn -> result end)

    ~H"""
    <div class="p-4 mb-4 text-sm text-red-800 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400" role="alert">
    <div class="flex space-x-4">
      <Heroicons.exclamation_circle class="w-6 h-6 text-red-900 fill-red-200" />
      <p>File Total record has the following issue(s): <%= error_to_string(@error) %></p>
    </div>
    </div>
    """
  end

  def record(%{item: {:file_total_record, :output, result}} = assigns) do
    assigns = assign_new(assigns, :result, fn -> result end)

    ~H"""
     <div class="p-4 mb-4 text-sm text-emerald-800 rounded-lg bg-emerald-50 dark:bg-gray-800 dark:text-emerald-400" role="alert">
    <div class="flex space-x-4">
      <Heroicons.check_circle class="w-6 h-6 text-green-900 fill-green-200" />
      <p>File Total record is good</p>
    </div>
    </div>
    """
  end

  def record(%{item: {:detail_record, :error, result}} = assigns) do
    assigns = assign_new(assigns, :error, fn -> result end)

    ~H"""
    <div class="p-4 mb-4 text-sm text-red-800 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400" role="alert">
    <div class="flex space-x-4">
      <Heroicons.exclamation_circle class="w-6 h-6 text-red-900 fill-red-200" />
      <p>Detail record has the following issue(s): <%= error_to_string(@error) %></p>
    </div>
    </div>
    """
  end

  def record(%{item: {:detail_record, :error, result, line}} = assigns) do
    assigns = assign_new(assigns, :error, fn -> result end)
    assigns = assign_new(assigns, :line, fn -> line end)

    ~H"""
    <div class="p-4 mb-4 text-sm text-red-800 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400" role="alert">
    <div class="flex space-x-4">
      <Heroicons.exclamation_circle class="w-6 h-6 text-red-900 fill-red-200" />
      <p>Detail record has the following issue(s) on line <%= @line %>: <%= error_to_string(@error) %></p>
    </div>
    </div>
    """
  end

  def record(%{item: {:detail_record, :ok, result}} = assigns) do
    assigns = assign_new(assigns, :result, fn -> result end)

    ~H"""

    <div class="p-4 mb-4 text-sm text-emerald-800 rounded-lg bg-emerald-50 dark:bg-gray-800 dark:text-emerald-400" role="alert">
    <div class="flex space-x-4">
      <Heroicons.check_circle class="w-6 h-6 text-green-900 fill-green-200" />
      <p>Detail record is good</p>
    </div>
    </div>
    """
  end

  def record(assigns) do
    assigns = assign_new(assigns, :bg_color, fn -> Enum.random(~w(bg-blue-200)) end)
    assigns = assign_new(assigns, :item, fn -> "" end)

    ~H"""
     <div class={"p-4 mb-4 text-sm rounded-lg #{@bg_color}"} role="alert">
    <div class="flex space-x-4">
      <p>Unmanaged view: </p>
      <%= inspect(@item) %>
    </div>
    </div>
    """
  end
end
