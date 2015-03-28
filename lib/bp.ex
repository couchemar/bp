defmodule Bp do

  defmodule Sync do
    defstruct [ pid: nil,
                request: [], block: [], wait: [],
                remove: false ]
  end

  require Logger

  def spawn do
    spawn(Bp, :loop, [[], []])
  end

  def loop(procs, syncs) do
    Process.flag(:trap_exit, true)
    Logger.debug fn ->
      "Processes: #{inspect procs} Sync requests: #{inspect syncs}"
    end
    receive do
      {:add, pid, prio} ->
        Process.link pid
        loop [{pid, prio} | procs], syncs
      {:sync, sync} when (1 + length(syncs)) == length(procs) ->
        Logger.debug fn -> "Prepare sync" end
        {new_procs, new_syncs} = do_sync procs, [sync | syncs]
        loop new_procs, new_syncs
      {:sync, sync}  ->
        loop procs, [sync | syncs]
      {:EXIT, pid, _reason} ->
        Logger.debug fn -> "Process #{inspect pid} terminated" end
        remove self(), pid
        loop procs, syncs
      other ->
        Logger.debug fn -> "Got message #{inspect other}" end
    end
  end

  def add(cpid, fun, prio) do
    pid = spawn fun
    send cpid, {:add, pid, prio}
    pid
  end

  def sync(cpid, s) do
    new_s = s |> _wait |> _pid
    send cpid, {:sync, new_s}
    receive do
      {:sync, event} -> event
    end
  end

  defp _wait(%Sync{wait: []} = s), do: %{s | wait: s.request}
  defp _wait(s), do: s

  defp _pid(%Sync{pid: nil} = s), do: %{s | pid: self}
  defp _pid(s), do: s

  def remove(cpid, pid) do
    send cpid, {:sync, %Sync{pid: pid, remove: true}}
  end

  defp do_sync(procs, syncs) do
    alive_syncs = drop_removed syncs
    alive_procs = keep_alive procs, alive_syncs

    proc_request = get_proc_requests alive_syncs
    prio_request = for {p, e} <- proc_request do
      {procs |> List.keyfind(p, 0) |> elem(1), e}
    end

    blocked = List.flatten(
      for %Bp.Sync{block: block} <- alive_syncs, do: block
    )

    events = for e = {_, r} <- prio_request, !Enum.member?(blocked, r), do: e

    case events do
      [] -> {alive_procs, alive_syncs}
      _ ->
        {_, e} = events |> List.keysort(0) |> hd
        {to_release, wait} = alive_syncs |> Enum.partition(
          fn(%Bp.Sync{wait: w, request: r}) ->
            Enum.member?(w, e) or Enum.member?(r, e)
          end
        )
        for %Bp.Sync{pid: pid} <- to_release do
          send pid, {:sync, e}
        end
        {alive_procs, wait}
    end
  end

  defp drop_removed(syncs) do
    syncs |> Enum.filter(fn(%Bp.Sync{remove: f}) -> !f end)
  end

  defp keep_alive(procs, syncs) do
    for {pid, prio} <- procs,
        %Bp.Sync{pid: keep} <- syncs,
        pid == keep do
          {pid, prio}
    end
  end

  defp get_proc_requests(syncs) do
    for %Bp.Sync{pid: pid, request: reqs} <- syncs,
        req <- reqs, do: {pid, req}
  end



end
