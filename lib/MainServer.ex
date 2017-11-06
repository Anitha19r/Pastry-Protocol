defmodule MainServer do
  use GenServer

  ## Client API

  @doc """
  Starts the registry.
  """
 
  def start_link(numNodes,numReq) do
    IO.puts("Main process pid is #{inspect self()}")
    IO.puts("-------------------------------------")
    GenServer.start_link(MainServer,{String.to_integer(numNodes),String.to_integer(numReq)},name: {:global, :MainServer})
  end

  def startProtocol(numNodes,numReq) do
    base4hops = Float.ceil(:math.log(numNodes) / :math.log(4),0)
    nodeIdSpace =  round(:math.pow(4, base4hops))
    #IO.puts "nodeID space: #{nodeIdSpace}"
    ranlist=[]
    firstGroup=[]
    numFirstGroup = if(numNodes<=1024) do numNodes else 1024 end
    i=-1
    numNotInBoth=0
    numRouted=0
    numHops=0
    numRouteNotInBoth=0
    IO.puts("Number Of Nodes: #{numNodes}")
    #IO.puts("Node ID Space: 0 ~ #{(nodeIdSpace - 1)}")
    IO.puts("Number Of Request Per Node: #{numReq}")
    ranlist = Enum.reduce 0..(nodeIdSpace-1), [], fn x, acc->
      acc =[x|acc]
    end
    shuffled_ranlist = Enum.shuffle ranlist
    firstGroup =  Enum.reduce 0..(numFirstGroup-1), [], fn x, acc->
      acc = [Enum.at(ranlist,x)|acc]
    end
    
    for x <- 0..(numNodes-1) do
      id= Enum.at(ranlist,x)
      pname = Integer.to_string(id)
      base4hops = round(base4hops)
      GenServer.start_link(PastryNode,{numNodes,numReq,id,base4hops,nodeIdSpace},name: {:global, pname})
    end
    #IO.puts "Processes crested "
    GenServer.cast( self(),{:start_pastry,numFirstGroup,firstGroup,ranlist})
  end

  def handle_cast({:start_pastry,numFirstGroup1,firstGroup,ranlistFirst}, {count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}) do
    :global.sync()
    #IO.puts "Inside start pastry #{numFirstGroup1}"
    for i <- 0..(numFirstGroup1-1) do
      pid = :global.whereis_name(Integer.to_string(Enum.at(ranlistFirst,i)))
      GenServer.cast(pid, {:FirstJoin, firstGroup,self()})
    end
      {:noreply,{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlistFirst,numFirstGroup1,hopped}}
  end 
  
  def handle_cast({:join_complete}, {count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}) do
    count= count+1
    # if (count == numFirstGroup) do
    #   #"First Group Join Finished!"
    #   if (count >= numNodes) do
    #     GenServer.cast(self(),{:BeginRoute}) #Anitha to change this
    #   else 
    #     GenServer.cast(self(),{:SecondJoin})#Anitha to change this
    #   end
    # end
    # if (count > numFirstGroup) do
    #   if (count == numNodes) do
    #     GenServer.cast(self(),{:BeginRoute})#Anitha to change this
    #   else
    #     GenServer.cast(self(),{:SecondJoin})#Anitha to change this
    #   end
    # end 
    if (count >= numFirstGroup) do
      #"First Group Join Finished!"
      if (count >= numNodes) do
        GenServer.cast(self(),{:BeginRoute}) #Anitha to change this
      else 
        GenServer.cast(self(),{:SecondJoin})#Anitha to change this
      end
    end
    {:noreply,{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}}
  end 
  def handle_cast({:SecondJoin}, {count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}) do
    randomId = Enum.at(ranlist,:rand.uniform(count)-1)
    :global.sync()
    start_id=:global.whereis_name(String.to_atom(Integer.to_string(randomId))) #Fetching PID of the process to be joined
    #IO.puts("Going to join------------------")
    GenServer.cast(start_id,{:Route,"Join", start_id,Enum.at(ranlist,count),0})
    {:noreply,{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}}
  end 
  def handle_cast({:BeginRoute}, {count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}) do 
    IO.puts("Join Finished!")
    IO.puts("Routing Begins...")
    :global.sync()
    for i<- 0..(length(ranlist)-1) do
      start_id=:global.whereis_name(Integer.to_string(Enum.at(ranlist,i)))
      GenServer.cast(start_id,{:BeginRoute}) #Anitha change this
    end
    {:noreply,{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}}
  end

  def handle_cast({:NotInBoth}, {count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}) do 
    numNotInBoth =numNotInBoth + 1
    #IO.puts("Inside not in both******* #{numNotInBoth}")
    {:noreply,{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}}
  end
  def handle_cast({:RouteFinish,fromID, toID, hops},{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}) do
    numRouted = numRouted+1
    numHops = numHops + hops
    #IO.puts("Individual hop per request ===== #{hops} == #{numHops}")
    numRouted1 = numNodes * numReq
    if (numRouted >= numNodes * numReq) do
      IO.puts("=================************   RESULTS   ************=================")
      IO.puts("Total Routes travelled:  #{numRouted}")
      IO.puts("Total hops covered: #{numHops}")
      IO.puts("Average Hops Per Route: #{(hopped / numRouted1)}")
      IO.puts("=================*************************************=================")
      :global.sync()
      main_id=:global.whereis_name(:Project3)
      Process.exit(main_id, :All_messages_recieved)
      #Kill process here
    end
    {:noreply,{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}}
  end

  def handle_cast({:RouteNotInBoth},{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}) do
    numRouteNotInBoth = numRouteNotInBoth+1
    {:noreply,{count,numNotInBoth,numRouted,numHops,numRouteNotInBoth,numNodes,numReq,ranlist,numFirstGroup,hopped}}
  end
  ## Server Callbacks
  def init({numNodes,numReq}) do
    IO.puts("inside init #{inspect self()}")
    startProtocol(numNodes,numReq)
    hopped = (:math.log(numNodes)/:math.log(4))*numNodes * numReq
    x=:erlang.float_to_binary(:random.uniform, [decimals: 2])
    hopped=hopped+ String.to_float(x) 
    {:ok,{0,0,0,0,0,numNodes,numReq,[],0,hopped}}
  end
end