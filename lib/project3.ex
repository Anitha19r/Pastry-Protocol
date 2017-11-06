defmodule Project3 do
  def main(argv) do
    {numNodes,numReq}=  
    if(length(argv) != 2) do
      IO.puts("Using default arguments! No. of nodes =1000 and no. of requests = 10")
      {1000,10}
    else 
      {String.to_integer(Enum.at(argv,0)),String.to_integer(Enum.at(argv,1))}
    end
    :global.register_name(:Project3, self()) 
    GenServer.start_link(MainServer,{numNodes,numReq},name: {:global, :MainServer})
    receive do
    end
  end
end
