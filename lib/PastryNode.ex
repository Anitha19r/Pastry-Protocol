defmodule PastryNode do
    use GenServer

    def init({numNodes,numRequests, id, base4hops,idSpace}) do
        table = %{}
        table= Enum.reduce 0..(base4hops-1), table, fn i, acc ->
             Map.put(acc,i,%{0=>-1,1=>-1,2=>-1,3=>-1})
        end
        #IO.puts("Node id is ------------>>>> #{toBase4String(id, base4hops)}")
        #IO.puts("init table #{inspect table}")
        {:ok,{[],[],0,idSpace,table,numNodes,numRequests, id, base4hops}}
    end

    def handle_cast({:FirstJoin,firstGroup,sender}, {largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}) do
        
        firstGroup=List.delete(firstGroup,id)
        {largerLeafSet,smallerLeafSet,table}=addLeafSet(id,firstGroup,largerLeafSet,smallerLeafSet,base4hops,table)
        #IO.puts" Inside first join #{inspect largerLeafSet} #{inspect smallerLeafSet} #{inspect table}"
        table=Enum.reduce 0..(base4hops-1), table, fn i, acc ->
            j= String.to_integer(String.at(toBase4String(id, base4hops),i))
            prev_map = acc[i]
            updated = %{prev_map|j => id}
            acc = %{acc | i => updated}
        end
        #IO.inspect(table)
        GenServer.cast(sender,{:join_complete})
        {:noreply,{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}}
    end
    def handle_cast({:Route,msg, fromID, toID, hops}, {largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}) do
        :global.sync()
	    #IO.puts("Inside handle hops #{inspect self()} #{hops}")
        #IO.puts("inside route ================= #{msg}")
        if (msg == "Join") do
            samePre = samePrefix(toBase4String(id, base4hops), toBase4String(toID, base4hops), 0)
            if (hops == 0 && samePre > 0) do
                for (i <- 0..samePre-1) do
                  GenServer.cast(Integer.to_string(toID), {:AddRow,i, table[i]})
                end
            end
            GenServer.cast(Integer.to_string(toID), {:AddRow,samePre, table[samePre]})
            #IO.puts " INside Join route for self: #{inspect self()}"
            cond do 
                ((length(smallerLeafSet) > 0 && toID >= Enum.min(smallerLeafSet) && toID <= id) || (length(largerLeafSet) > 0 && toID <= Enum.max(largerLeafSet) && toID >= id)) ->
                    diff = idSpace + 10
                    nearest = -1
                    [nearest,diff]=
                    if (toID < id) do
                        [nearest,diff]=Enum.reduce smallerLeafSet, [nearest,diff], fn i,acc ->
                            if (abs(toID - i) < Enum.at(acc,1)) do
                                List.replace_at(acc,0, i)
                                List.replace_at(acc,1,abs(toID - i))
                            end
                            acc=acc
                        end
                    else 
                        [nearest,diff]=Enum.reduce largerLeafSet, [nearest,diff], fn i,acc ->
                            if (abs(toID - i) < Enum.at(acc,1)) do
                                List.replace_at(acc,0, i)
                                List.replace_at(acc,1,abs(toID - i))
                            end
                            acc=acc
                        end
                    end
                    if (abs(toID - id) > diff) do
                        GenServer.cast(Integer.to_string(nearest), {:Route,msg, fromID, toID, hops+ 1})
                    else 
                        allLeaf = []
                        allLeaf ++[id] ++ [smallerLeafSet]++[largerLeafSet]
                        #allLeaf = largerLeafSet ++ allLeaf
                        #allLeaf =[id|smallerLeafSet|largerLeafSet| allLeaf] 
                        GenServer.cast(Integer.to_string(toID),{:AddLeaf,allLeaf}) 
                    end
                (length(smallerLeafSet) < 4 && length(smallerLeafSet) > 0 && toID < Enum.min(smallerLeafSet)) ->
                    GenServer.cast(Integer.to_string(Enum.min(smallerLeafSet)),{:Route,msg, fromID, toID, hops+ 1})
                (length(largerLeafSet) < 4 && length(largerLeafSet) > 0 && toID > Enum.max(largerLeafSet)) ->
                    GenServer.cast(Integer.to_string(Enum.max(largerLeafSet)),{:Route,msg, fromID, toID, hops+ 1})
                ((length(smallerLeafSet) == 0 && toID < id) || (length(largerLeafSet) == 0 && toID > id)) ->
                    allLeaf = []
                    allLeaf ++[id] ++ [smallerLeafSet]++[largerLeafSet]
                    #allLeaf =[id|smallerLeafSet|largerLeafSet| allLeaf] 
                    #allLeaf = id ++ smallerLeafSet
                    #allLeaf = largerLeafSet ++ allLeaf
                    GenServer.cast(Integer.to_string(toID), {:AddLeaf,allLeaf})
                (table[samePre][String.to_integer(String.at(toBase4String(toID, base4hops),samePre))]) != -1 ->
                    GenServer.cast(Integer.to_string(table[samePre][String.to_integer(String.at(toBase4String(toID, base4hops),samePre))]),{:Route,msg, fromID, toID, hops+ 1})
                (toID > id) ->
                    GenServer.cast(Integer.to_string(Enum.max(largerLeafSet)),{:Route,msg, fromID, toID, hops+ 1})
                    #GenServer.cast(:global.whereis_name(:MainServer),{:NotInBoth})
                (toID < id) ->
                    GenServer.cast(Integer.to_string(Enum.min(smallerLeafSet)),{:Route,msg, fromID, toID, hops+ 1})
                    #GenServer.cast(:global.whereis_name(:MainServer),{:NotInBoth})
                true ->  
                    IO.puts("Impossible!!!")
            end
    
        else 
            #IO.puts("Sending mssgs form id : #{id} to id #{toID}")
            if (id == toID) do
                GenServer.cast(:global.whereis_name(:MainServer),{:RouteFinish,fromID, toID, hops+ 1})
            else 
                samePre = samePrefix(toBase4String(id, base4hops), toBase4String(toID, base4hops), 0)
                #IO.puts("Checking same pre========== #{samePre} hops======== #{hop}")
                cond do
                    ((length(smallerLeafSet) > 0 && toID >= Enum.min(smallerLeafSet) && toID < id) || (length(largerLeafSet) > 0 && toID <= Enum.max(largerLeafSet) && toID > id)) ->
                        diff = idSpace + 10
                        nearest = -1
                        [nearest,diff]=
                        if (toID < id) do
                            [nearest,diff]=Enum.reduce smallerLeafSet, [nearest,diff], fn i,acc ->
                                if (abs(toID - i) < Enum.at(acc,1)) do
                                    List.replace_at(acc,0, i)
                                    List.replace_at(acc,1,abs(toID - i))
                                end
                                acc=acc
                            end
                        else 
                            [nearest,diff]=Enum.reduce largerLeafSet, [nearest,diff], fn i,acc ->
                                if (abs(toID - i) < Enum.at(acc,1)) do
                                    List.replace_at(acc,0, i)
                                    List.replace_at(acc,1,abs(toID - i))
                                end
                                acc=acc
                            end
                        end
                        if (abs(toID - id) > diff) do
                            GenServer.cast(Integer.to_string(nearest), {:Route,msg, fromID, toID, hops+ 1})
                        else 
                            GenServer.cast(:global.whereis_name(:MainServer),{:RouteFinish,fromID, toID, hops+ 1})
                        end
                    (length(smallerLeafSet) < 4 && length(smallerLeafSet) > 0 && toID < Enum.min(smallerLeafSet)) ->
                        GenServer.cast(Integer.to_string(Enum.min(smallerLeafSet)),{:Route,msg, fromID, toID, hops+ 1})
                    (length(largerLeafSet) < 4 && length(largerLeafSet)> 0 && toID > Enum.max(largerLeafSet)) ->
                        GenServer.cast(Integer.to_string(Enum.max(largerLeafSet)),{:Route,msg, fromID, toID, hops+ 1})
                    ((length(smallerLeafSet) == 0 && toID < id) || (length(largerLeafSet) == 0 && toID > id)) ->
                        GenServer.cast(:global.whereis_name(:MainServer),{:RouteFinish,fromID, toID, hops+ 1})
                    (table[samePre][String.to_integer(String.at(toBase4String(toID, base4hops),samePre))] != -1) ->
                        GenServer.cast(Integer.to_string(table[samePre][String.to_integer(String.at(toBase4String(toID, base4hops),samePre))]),{:Route,msg, fromID, toID, hops+ 1})
                    (toID > id) ->
                        GenServer.cast(Integer.to_string(Enum.max(largerLeafSet)),{:Route,msg, fromID, toID, hops + 1})
                        #GenServer.cast(:global.whereis_name(:MainServer),{:RouteNotInBoth})
                    (toID < id) ->
                        GenServer.cast(Integer.to_string(Enum.min(smallerLeafSet)),{:Route,msg, fromID, toID, hops+ 1})
                        #GenServer.cast(:global.whereis_name(:MainServer),{:RouteNotInBoth})
                    true -> 
                        IO.puts("Impossible!!!")
                end #cond end
            end #if id==toID
        end #if msg ==Join
        {:noreply,{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}}
    end
    def handle_cast({:AddRow,rowNum, newRow},{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}) do
        # table=Enum.reduce 0..3, table, fn i, acc ->
        #     prev_map = acc[rowNum]
        #     if (table[rowNum][i] == -1) do
        #         updated = %{prev_map|i => newRow[i]}
        #         acc = %{acc | rowNum => newRow}
        #     end
        #     acc=acc
        # end
        table = %{table | rowNum => newRow}
        {:noreply,{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}}
    end

    def handle_cast({:AddLeaf,allLeaf} ,{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}) do
        {largerLeafSet,smallerLeafSet,table}=addLeafSet(id,allLeaf,largerLeafSet,smallerLeafSet,base4hops,table)
        for i<- smallerLeafSet do
            GenServer.cast(Integer.to_string(i), {:UpdateMe,id,self()})
        end
        for i<- largerLeafSet do
            GenServer.cast(Integer.to_string(i), {:UpdateMe,id,self()})
        end
        numOfBack = numOfBack+ length(largerLeafSet)+length(smallerLeafSet)
        numOfBack = Enum.reduce 0..(base4hops-1), numOfBack,fn i,acc -> 
            Enum.reduce 0..(base4hops-1), acc,fn j,acc1 -> 
                if (table[i][j] != -1) do
                    acc1=acc1+1
                end
                GenServer.cast(Integer.to_string(table[i][j]), {:UpdateMe,id,self()})
                acc1=acc1
            end
            acc = acc
        end
        table=Enum.reduce 0..(base4hops-1), table,fn i,acc -> 
            j=String.to_integer(String.at(toBase4String(id, base4hops),i))
            prev_map = acc[i]
            updated = %{prev_map|j => id}
            acc = %{acc | i => updated}
            acc = acc
        end
        {:noreply,{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}}
    end

    def handle_cast({:UpdateMe,newNodeID,sender},{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}) do
        {largerLeafSet,smallerLeafSet,table}=addLeafSet(id,[newNodeID],largerLeafSet,smallerLeafSet,base4hops,table)
        GenServer.cast(Integer.to_string(newNodeID),{:Ack})
        {:noreply,{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}}
    end

    def handle_cast({:Ack},{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}) do
        numOfBack =numOfBack- 1
        if (numOfBack == 0) do
            GenServer.cast(:global.whereis_name(:MainServer),{:join_complete})
        end
        {:noreply,{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}}
    end


    def handle_cast({:BeginRoute},{largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}) do
        for (i <- 1..numRequests) do
            :timer.sleep(2000)
            listneigh = Enum.to_list(0..idSpace-1)
            destination = Enum.random(List.delete(listneigh, id))
            if destination == id do
                IO.inspect "I shouldnt be picked as im self"
            end
            #IO.puts "idspace value: #{idSpace}"
            GenServer.cast(self(),{:Route,"Route", id, destination, 0})
        end
        {:noreply, {largerLeafSet,smallerLeafSet,numOfBack, idSpace,table,numNodes,numRequests, id, base4hops}}
    end


    def addLeafSet(id,list,largerLeafSet,smallerLeafSet,base4hops,table) do
        #IO.puts ("inside add leaf set ------------- #{inspect list}") 
        largerLeafSet= if length(largerLeafSet) == 0 do largerLeafSet=[] end
        largerLeafSet=Enum.reduce list , largerLeafSet , fn(curr_id , acc) ->
            if acc == nil do acc =[] end
            if curr_id > id && !Enum.member?(acc,curr_id) do
                if length(acc) < 4 do
                    [curr_id|acc]
                else
                    if curr_id  < Enum.max(acc) do
                        acc = List.delete(acc,Enum.max(acc))
                        [curr_id|acc]
                    end
                end
            end
            acc=acc
        end
        smallerLeafSet=Enum.reduce list , smallerLeafSet , fn(curr_id , acc) ->
            if curr_id < id && !Enum.member?(acc,curr_id) do
                if length(acc) < 4 do
                    [curr_id|acc]
                else
                    if curr_id  > Enum.min(acc) do
                        acc = List.delete(acc,Enum.min(acc))
                        [curr_id|acc]
                    end
                end
            end
            acc=acc
        end
        #IO.inspect list
        #IO.inspect table
        table = Enum.reduce list , table , fn(i , acc) ->
            samePre = samePrefix(toBase4String(id, base4hops), toBase4String(i, base4hops), 0)
            j=String.to_integer(String.at(toBase4String(id, base4hops),samePre))
            #IO.puts("hhhhhdhfhdfhkdhfkdfhgkhdfk    value of j #{j}")
            if (acc[samePre][j] == -1) do
                prev_map = acc[samePre]
                updated = %{prev_map|j => i}
                acc = %{acc | samePre => updated}
            end
            acc = acc
        end
        #IO.inspect table
        {largerLeafSet,smallerLeafSet,table}
    end

    def toBase4String(id, length) do
        baseNodeID = Integer.to_string(id,4)
        String.pad_leading(baseNodeID, length, "0")
    end
    
    def samePrefix(id1,id2, position) do
        if String.first(id1) != String.first(id2) do
            position
        else
            samePrefix(String.slice(id1,1..(String.length(id1)-1)),String.slice(id2,1..(String.length(id2)-1)), position+1 )
        end
    end

end
