defmodule Bp do

  defmodule Sync do
    defstruct [ pid: nil,
                request: [], block: [], wait: [],
                remove: false ]
  end

  require Logger

  def spawn do
    spawn(Bp, :loop, [false, [], []])
  end

  def loop(start, procs, syncs) do
    Process.flag(:trap_exit, true)
    Logger.debug fn ->
      "Processes: #{inspect procs} Sync requests: #{inspect syncs}"
    end
    receive do
      :start -> loop true, procs, syncs
      {:add, pid, prio} ->
        Process.link pid
        loop start, [{pid, prio} | procs], syncs
      {:sync, sync} when start ->
        Logger.debug fn -> "Got sync message #{inspect sync}" end
        {new_procs, new_syncs} = do_sync procs, [sync | syncs]
        loop start, new_procs, new_syncs
      {:EXIT, pid, _reason} ->
        Logger.debug fn -> "Process #{inspect pid} terminated" end
        remove self(), pid
        loop start, procs, syncs
    end
  end

  def start(cpid), do: send(cpid, :start)

  def add(cpid, fun), do: add(cpid, fun, 0)
  def add(cpid, fun, prio) do
    pid = spawn fun
    send cpid, {:add, pid, prio}
    pid
  end

  def sync(cpid, s) do
    send cpid, {:sync, s |> _wait |> _pid}
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

  defp do_sync(procs, syncs) when length(procs) == length(syncs) do
    Logger.debug fn() -> "Doing sync" end
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
        Logger.debug fn() -> "Send #{inspect e} to #{inspect to_release}" end
        for %Bp.Sync{pid: pid} <- to_release do
          send pid, {:sync, e}
        end
        {alive_procs, wait}
    end
  end
  defp do_sync(procs, syncs), do: {procs, syncs}

  defp drop_removed(syncs),
  do: syncs |> Enum.filter(fn(%Bp.Sync{remove: f}) -> !f end)

  defp keep_alive(procs, syncs) do
    for {pid, prio} <- procs,
        %Bp.Sync{pid: keep} <- syncs,
        pid == keep, do: {pid, prio}
  end

  defp get_proc_requests(syncs) do
    for %Bp.Sync{pid: pid, request: reqs} <- syncs, req <- reqs, do: {pid, req}
  end

end
