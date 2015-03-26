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
    send cpid, %Sync{pid: pid, remove: true}
  end

  defp do_sync(procs, syncs) do
    alive_syncs = drop_removed syncs
    alive_procs = keep_alive procs, alive_syncs
    {procs, syncs}
  end

  defp drop_removed(syncs) do
    syncs |> Enum.filter(fn(%Bp.Sync{remove: f}) -> !f end)
  end

  defp keep_alive(procs, syncs) do
  end


  defmodule Test do

    def display do
      event = Bp.sync :bp, %Bp.Sync{wait: [:morning, :evening]}
      IO.puts "Good #{inspect event}"
      display
    end

    def morning do
      for _ <- 1..3 do
        Bp.sync :bp, %Bp.Sync{wait: [:morning],
                              request: [:morning]}
      end
    end

    def evening do
      for _ <- 1..3 do
        Bp.sync :bp, %Bp.Sync{wait: [:evening],
                              request: [:evening]}
      end
    end

    def interleave do
      Bp.sync :bp, %Bp.Sync{wait: [:morning],
                            block: [:evening]}
      Bp.sync :bp, %Bp.Sync{wait: [:evening],
                            block: [:morning]}
      interleave
    end

    def test do
      bc = Bp.spawn
      Process.register bc, :bp
      Bp.add :bp, &morning/0, 1
      Bp.add :bp, &display/0, 2
      Bp.add :bp, &evening/0, 3
      Bp.add :bp, &interleave/0, 4
    end

  end

end
