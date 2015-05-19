# Boundary Meter Debug

Examines the running components which have matched based on the regex provided and reports information on those specific process.
Note: Currently only supports systems which have ps.

## Prerequisites

### Supported OS

|     OS    | Linux | Windows | SmartOS | OS X |
|:----------|:-----:|:-------:|:-------:|:----:|
| Supported |   v   |    -    |    -    |  v   |

#### Boundary Meter Versions V4.0 Or Later

- To install new meter go to Settings->Installation or [see instructons](https://help.boundary.com/hc/en-us/sections/200634331-Installation).
- To upgrade the meter to the latest version - [see instructons](https://help.boundary.com/hc/en-us/articles/201573102-Upgrading-the-Boundary-Meter).

### Plugin Setup
None

#### Plugin Configuration Fields

|Field Name     |Description                                                                       |
|:--------------|:---------------------------------------------------------------------------------|
|Name           |The name to associate with the matched process (if not present will use match)    |
|Match          |The string against which to match to find and report on the given process(es)     |
|Poll Time (sec)|The Poll Interval to send a ping to the host in seconds. Ex. 5                    |

### Metrics Collected

|Metric Name       |Description                            |
|:-----------------|:--------------------------------------|
|CPU_PROCESS       |The percentage of the CPU being consumed by the process|
|MEM_PROCESS       |The percentage of the memory being consumed by the process|
|RMEM_PROCESS      |The number of resident in-memory bytes being consumed by the process|
|VMEM_PROCESS      |The number of virtual memory bytes being consumed by the process|
|TIME_PROCESS      |The number of CPU seconds which have been consumed by the process|
