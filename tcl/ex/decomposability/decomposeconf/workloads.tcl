# config file for remy simulations
global opt

# source, sink, and app types
set opt(tcp) TCP/Rational
set opt(sink) TCPSink

# AQM details
set opt(gw) DropTail;            # queueing at bottleneck
set opt(maxq) 1000;              # max queue length at bottleneck
set opt(rcvwin) 65536

# app parameters
set opt(app) FTP/OnOffSender
set opt(pktsize) 1200;           # doesn't include proto headers

# random on-off times for sources
set opt(seed) 0
set opt(onrand) Exponential
set opt(offrand) Exponential
set opt(onavg) 5.0;              # mean on and off time
set opt(offavg) 0.2;             # mean on and off time
set opt(avgbytes) 100000;        # 16 KBytes flows on avg (too low?)
set opt(ontype) "bytes";         # valid options are "bytes" and "flowcdf"
set opt(reset) "false";          # reset TCP on end of ON period
set opt(spike) "false";          # spike is false by default

# simulator parameters
set opt(simtime) 100.0;          # total simulated time
#set opt(tr) remyout;            # output trace in opt(tr).out
set opt(partialresults) false;   # show partial throughput, delay, and utility?
set opt(verbose) false;          # verbose printing for debugging (esp stats)
set opt(checkinterval) 0.005;    # check stats every 5 ms

# utility and scoring
set opt(alpha) 1.0
set opt(tracewhisk) "none";      # give a connection ID to print for that flow, or give "all"

# tcp details
Agent/TCP set tcpTick_ .0001
Agent/TCP set timestamps_ true
set opt(hdrsize) 50
set opt(flowoffset) 40
