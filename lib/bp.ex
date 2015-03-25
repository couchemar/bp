defmodule Bp do

  defmodule Sync do
    defstruct request: [], block: [], wait: []
  end

  require Logger

  def spawn do
    spawn(Bp, :loop, [[], []])
  end

  def loop(procs, syncs) do
    Logger.debug fn -> "#{inspect procs} #{inspect syncs}" end
    receive do
      {:add, pid} ->
        loop([pid | procs], syncs)
      {:sync, sync} when length(syncs) < length(procs) ->
        loop(procs, [sync | syncs])
      {:sync, sync} ->
        {new_procs, new_syncs} = do_sync(procs, [sync | syncs])
        loop(new_procs, new_syncs)
    end
  end

  def add(cpid, fun) do
    pid = spawn(fun)
    send(cpid, {:add, pid})
    pid
  end

  def sync(cpid, %Sync{wait: []} = s) do
    new_s = %{s | wait: s.request}
    send cpid, {:sync, new_s}
  end

  defp do_sync(procs, syncs) do
    {procs, syncs}
  end

end
