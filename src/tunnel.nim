import std/[asyncdispatch, nativesockets, strformat, strutils, net, tables, random, endians]
import overrides/[asyncnet]
import times, print, connection, pipe, openssl
from globals import nil

when defined(windows):
    from winlean import getSockOpt
else:
    from posix import getSockOpt

type
    TunnelConnectionPoolContext = object
        listener_server: Connection
        listener: Connection
        user_inbound: Connections
        peer_inbound: Connections
        peer_ips:seq[IpAddress]
var context = TunnelConnectionPoolContext()

proc monitorData(data: string): (bool,IpAddress) =
    var ip = IpAddress(family : IpAddressFamily.IPv4)
    try:

        var sh1_c: uint32
        var sh2_c: uint32

        copyMem(unsafeAddr sh1_c, unsafeAddr data[0], 4)
        copyMem(unsafeAddr sh2_c, unsafeAddr data[4], 4)
        # copyMem(unsafeAddr port, unsafeAddr data[8], 4)

        let chk1 = sh1_c == globals.sh1
        let chk2 = sh2_c == globals.sh2

        if (chk1 and chk2):
            var fm :char = 0.char
            copyMem(unsafeAddr fm, unsafeAddr data[9], 1)
            if fm == 4.char :
                if len(data) < 10+globals.self_ip.address_v4.len: return (false,ip)

                copyMem(unsafeAddr ip.address_v4, unsafeAddr data[10], ip.address_v4.len)

            elif fm == 6.char:
                if len(data) < 10+globals.self_ip.address_v6.len: return (false,ip)

                copyMem(unsafeAddr ip.address_v6, unsafeAddr data[10], ip.address_v6.len)

            else:
                return (false,ip)

            return (true,ip)
        else:
            return (false,ip)

    except:
        return (false,ip)




proc processConnection(client: Connection) {.async.} =
    var remote: Connection = nil
    var data = ""
    var processRemoteFuture:Future[void]

    var closed = false
    proc close() =
        if not closed:
            closed = true
            if globals.log_conn_destory: echo "[processRemote] closed client & remote"
            if remote != nil:
                remote.close()

            client.close()

    proc remoteUnTrusted(): Future[Connection]{.async.} =
        var new_remote = newConnection()
        new_remote.trusted = TrustStatus.no
        await new_remote.socket.connect(globals.final_target_ip, globals.final_target_port.Port)
        # if globals.log_conn_create: echo "connected to ", globals.final_target_domain, ":", $globals.final_target_port
        return new_remote


    proc processRemote() {.async.} =
        try:
            while (not remote.isNil()) and (not remote.isClosed) and (not client.isClosed):
                data = await remote.recv(globals.chunk_size)
                if globals.log_data_len: echo &"[processRemote] {data.len()} bytes from remote"

                if remote.isTrusted:
                    normalRead(data)

                if not client.isClosed:
                    await client.send(data)
                    if globals.log_data_len: echo &"[processRemote] {data.len} bytes -> client "

                if data.len() == 0:
                    break

        except: discard
        
        if not remote.isNil():remote.close()
        if remote.isTrusted:
            client.close()

    proc chooseRemote() {.async.} =
          

        for i in 0..<16:
            remote = context.peer_inbound.grab()
            if remote != nil: break
            await sleepAsync(100)

        if remote != nil:
            if globals.log_conn_create: echo &"[createNewCon][Succ] Associated a peer connection"
            asyncCheck processRemote()
        else:
            if globals.log_conn_destory: echo &"[createNewCon][Error] left without connection, closes forcefully."
            client.close()

    proc processClient() {.async.} =
        try:
            while not client.isClosed:
                    data = await client.recv(globals.chunk_size)
                    if globals.log_data_len: echo &"[processClient] {data.len()} bytes from client {client.id}"

                    if client.trusted == TrustStatus.pending:
                        var (trust,ip) = monitorData(data)
                        if trust:
                            #peer connection
                            client.trusted = TrustStatus.yes
                            print "Peer Fake Handshake Complete ! ",ip
                            context.peer_inbound.register(client)
                            context.peer_ips.add(ip)
                            remote.close() # close untrusted remote
                            await processRemoteFuture

                            block finish_handshake:
                                let rlen = 16*(8+rand(8))
                                var random_trust_data: string
                                random_trust_data.setLen(rlen)
                                copyMem(unsafeAddr random_trust_data[0], unsafeAddr globals.sh3.uint32, 4)
                                copyMem(unsafeAddr random_trust_data[4], unsafeAddr globals.sh4.uint32, 4)
                                copyMem(unsafeAddr random_trust_data[8], unsafeAddr(globals.random_600[rand(250)]), rlen-8)

                                if globals.multi_port:
                                    copyMem(unsafeAddr random_trust_data[8], unsafeAddr client.port, 4)
                                await client.unEncryptedSend(random_trust_data)

                            return 
                        else:
                            if context.peer_ips.len > 0 and 
                             context.peer_ips[0] != client.address:
                                #user connection
                                echo "Real User connected !"
                                client.trusted = TrustStatus.no
                                remote.close()
                                await processRemoteFuture
                                # await sleepAsync(4)
                                # asyncdispatch.poll()
                                # context.user_inbound.register(client) not required
                                await chooseRemote() #associate peer
                                if remote == nil: break

                            elif (epochTime().uint - client.creation_time) > globals.trust_time:
                                #user connection but no peer connected yet
                                #peer connection but couldnt finish handshake in time
                                client.trusted = TrustStatus.no
                                break


                    if not remote.isClosed:
                        if remote.isTrusted:
                            normalSend(data)
                        await remote.send(data)
                        if globals.log_data_len: echo &"{data.len} bytes -> Remote"

                    
                    if data.len() == 0:
                        break

        except: discard
        close()

    try:
        remote = await remoteUnTrusted()
        processRemoteFuture = processRemote()
        asyncCheck processClient()

    except:
        printEx()

proc start*(){.async.} =
    var pbuf = newString(len = 16)

    proc start_server_listener(){.async.} =

        context.listener_server = newConnection()
        context.listener_server.socket.setSockOpt(OptReuseAddr, true)
        context.listener_server.socket.bindAddr(8093.Port, globals.listen_addr)
       

        echo &"Started tcp server... {globals.listen_addr}:{globals.listen_port}"
        context.listener_server.socket.listen()

        while true:
            let (address, client) = await context.listener_server.socket.acceptAddr()
                  
            var con = newConnection(client,"192.168.1.130")
           
            con.port = globals.listen_port
            if globals.log_conn_create: print "Connected reverse host: ", address

            asyncCheck processConnection(con)
    proc start_users_listener(){.async.} =

        context.listener = newConnection()
        context.listener.socket.setSockOpt(OptReuseAddr, true)
        context.listener.socket.bindAddr(globals.listen_port.Port, globals.listen_addr)
        if globals.multi_port:
            globals.listen_port = getSockName(context.listener.socket.getFd().SocketHandle).uint32
            globals.createIptablesRules()

        echo &"Started tcp server... {globals.listen_addr}:{globals.listen_port}"
        context.listener.socket.listen()

        while true:
            let (address, client) = await context.listener.socket.acceptAddr()
                  
            var con = newConnection(client,address)
            if globals.multi_port:
                var origin_port: cushort
                var size = 16.SockLen
                if getSockOpt(con.socket.getFd().SocketHandle, cint(globals.SOL_IP), cint(globals.SO_ORIGINAL_DST),
                addr(pbuf[0]), addr(size)) < 0'i32:
                    echo "multiport failure getting origin port. !"
                    continue
                bigEndian16(addr origin_port, addr pbuf[2])

                con.port = origin_port
                if globals.log_conn_create: print "Connected client: ", address, " : ", con.port
            else:
                con.port = globals.listen_port

                if globals.log_conn_create: print "Connected client: ", address

            asyncCheck processConnection(con)


    await sleepAsync(2500)
    echo &"Mode Tunnel (usecase: IRAN server):  {globals.self_ip} <->  {globals.next_route_addr} handshake: {globals.final_target_domain}"
    asyncCheck start_users_listener()
    asyncCheck start_server_listener()





