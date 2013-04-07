# Author : Hari Balakrishnan
# Class that simulates random on/off traffic, where
# on and off durations are drawn from a specific distribution.
source timer.tcl

Class LoggingApp -superclass {Application Timer}

LoggingApp instproc init {id} {
    $self instvar srcid_ nbytes_ cumrtt_ numsamples_ u_ offtotal_ on_ranvar_ off_ranvar_
    global opt
    $self set srcid_ $id
    $self set nbytes_ 0
    $self set cumrtt_ 0.0
    $self set numsamples_ 0
    $self set u_ [new RandomVariable/Uniform]
    $self set offtotal_ 0.0

    # Create exponential on/off RandomVariables
    $self set on_ranvar_  [new RandomVariable/$opt(onrand)]
    $self set off_ranvar_ [new RandomVariable/$opt(offrand)]
    if { $opt(ontype) == "time" } {
        $on_ranvar_ set avg_ $opt(onavg)
    } elseif { $opt(ontype) == "bytes" } {
            $on_ranvar_ set avg_ $opt(avgbytes)
    } elseif { $opt(ontype) == "flowcdf" } {
        source $flowfile
    }
    set off_ranvar_ [new RandomVariable/$opt(offrand)]
    $off_ranvar_ set avg_ $opt(offavg)

    $self settype
    $self next
}

LoggingApp instproc settype { } {
    $self instvar endtime_ maxbytes_ 
    global opt
    if { $opt(ontype) == "time" } {
        $self set maxbytes_ "infinity"; # not byte-limited
        $self set endtime_ 0
    } else {
        $self set endtime_ $opt(simtime)
        $self set maxbytes_ 0        
    }
}

# called at the start of the simulation for the first run
LoggingApp instproc go { starttime } {
    $self instvar maxbytes_ endtime_ laststart_ srcid_ state_ u_ on_ranvar_
    global ns opt src flowcdf

    set laststart_ $starttime
    $ns at $starttime "$src($srcid_) start"    
    if { $starttime >= [$ns now] } {
        set state_ ON
        if { $opt(ontype) == "bytes" } {
            set maxbytes_ [$on_ranvar_ value]; # in bytes
        } elseif  { $opt(ontype) == "time" } {
            set endtime_ [$on_ranvar_ value]; # in time
        } else {
            $u_ set min_ 0.0
            $u_ set max_ 1.0
            set r [$u_ value]
            set idx [expr int(100000*$r)]
            if { $idx > [llength $flowcdf] } {
                set idx [expr [llength $flowcdf] - 1]
            }
            set maxbytes_ [expr 40 + [lindex $flowcdf $idx]]
#            puts "Flow len $maxbytes_"
        }
        # puts "$starttime: Turning on $srcid_ for $maxbytes_ bytes $endtime_ sec"

    } else {
        $self sched [expr $starttime - [$ns now]]
        set state_ OFF
    }
}

LoggingApp instproc timeout {} {
    $self instvar srcid_ maxbytes_ endtime_
    global ns src
    $self recv 0
    $self sched 0.1
}

LoggingApp instproc recv { bytes } {
    # there's one of these objects for each src/dest pair 
    $self instvar nbytes_ srcid_ cumrtt_ numsamples_ maxbytes_ endtime_ laststart_ state_ u_ offtotal_ off_ranvar_ on_ranvar_
    global ns opt src tcp_senders stats flowcdf

    if { $state_ == OFF } {
        if { [$ns now] >= $laststart_ } {
#            puts "[$ns now]: wasoff turning $srcid_ on for $maxbytes_"
            set state_ ON
        }
    }
    
    if { $state_ == ON } {
        if { $bytes > 0 } {
            set nbytes_ [expr $nbytes_ + $bytes]
            set tcp_sender [lindex $tcp_senders($srcid_) 0]
            set rtt_ [expr [$tcp_sender set rtt_] * [$tcp_sender set tcpTick_]]
            if {$rtt_ > 0.0} {
                set cumrtt_ [expr $rtt_  + $cumrtt_]
                set numsamples_ [expr $numsamples_ + 1]
            }
        }
        set ontime [expr [$ns now] - $laststart_]
        if { $nbytes_ >= $maxbytes_ || $ontime >= $endtime_ || $opt(simtime) <= [$ns now]} {
#            puts "[$ns now]: Turning off $srcid_ ontime $ontime"
            $ns at [$ns now] "$src($srcid_) stop"
            $stats($srcid_) update $nbytes_ $ontime $cumrtt_ $numsamples_
            set nbytes_ 0
            set state_ OFF
            set nexttime [expr [$ns now] + [$off_ranvar_ value]]; # stay off until nexttime
            set offtotal_ [expr $offtotal_ + $nexttime - [$ns now]]
#            puts "OFFTOTAL for src $srcid_ $offtotal_"
            set laststart_ $nexttime
            if { $nexttime < $opt(simtime) } { 
                # set up for next on period
                if { $opt(ontype) == "bytes" } {
                    set maxbytes_ [$on_ranvar_ value]; # in bytes
                } elseif  { $opt(ontype) == "time" } {
                    set endtime_ [$on_ranvar_ value]; # in time
                } else {
                    set r [$u_ value]
                    set maxbytes_ [expr 40 + [ lindex $flowcdf [expr int(100000*$r)]]]
                }
                $ns at $nexttime: "$src($srcid_) start"; # schedule next start
#                puts "@$nexttime: Turning on $srcid_ for $maxbytes_ bytes $endtime_ s"
            }
        }
        return nbytes_
    }
}

LoggingApp instproc results {} {
    $self instvar nbytes_ cumrtt_ numsamples_
    return [list $nbytes_ $cumrtt_ $numsamples_]
}

LoggingApp instproc sample_off_duration {} {
    $self instvar off_ranvar_
    return [$off_ranvar_ value]
}
