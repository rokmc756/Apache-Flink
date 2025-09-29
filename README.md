### Apache Flink Architecture?
Flink is a distributed system and requires effective allocation and management of compute resources in order to execute streaming applications.
It integrates with all common cluster resource managers such as Hadoop YARN and Kubernetes, but can also be set up to run as a standalone cluster or even as a library.

This section contains an overview of Flink’s architecture and describes how its main components interact to execute applications and recover from failures.

### The Anatomy of a Apache Flink Cluster
The Flink runtime consists of two types of processes: a JobManager and one or more TaskManagers.
<p align="center">
<img src="https://github.com/rokmc756/Apache-Flink/blob/main/roles/flink/images/apache-flink-architecture.svg" width="80%" height="80%">
</p>

The Client is not part of the runtime and program execution, but is used to prepare and send a dataflow to the JobManager. After that, the client can disconnect (detached mode), or stay connected to receive progress reports (attached mode). The client runs either as part of the Java program that triggers the execution, or in the command line process ./bin/flink run ....

The JobManager and TaskManagers can be started in various ways: directly on the machines as a standalone cluster, in containers, or managed by resource frameworks like YARN. TaskManagers connect to JobManagers, announcing themselves as available, and are assigned work.

#### JobManager
The JobManager has a number of responsibilities related to coordinating the distributed execution of Flink Applications: it decides when to schedule the next task (or set of tasks), reacts to finished tasks or execution failures, coordinates checkpoints, and coordinates recovery on failures, among others. This process consists of three different components:

- ResourceManager
The ResourceManager is responsible for resource de-/allocation and provisioning in a Flink cluster — it manages task slots, which are the unit of resource scheduling in a Flink cluster (see TaskManagers). Flink implements multiple ResourceManagers for different environments and resource providers such as YARN, Kubernetes and standalone deployments. In a standalone setup, the ResourceManager can only distribute the slots of available TaskManagers and cannot start new TaskManagers on its own.
- Dispatcher
The Dispatcher provides a REST interface to submit Flink applications for execution and starts a new JobMaster for each submitted job. It also runs the Flink WebUI to provide information about job executions.
- JobMaster
A JobMaster is responsible for managing the execution of a single JobGraph. Multiple jobs can run simultaneously in a Flink cluster, each having its own JobMaster.

There is always at least one JobManager. A high-availability setup might have multiple JobManagers, one of which is always the leader, and the others are standby (see High Availability (HA)).

#### TaskManagers
The TaskManagers (also called workers) execute the tasks of a dataflow, and buffer and exchange the data streams.

There must always be at least one TaskManager. The smallest unit of resource scheduling in a TaskManager is a task slot.
The number of task slots in a TaskManager indicates the number of concurrent processing tasks.
Note that multiple operators may execute in a task slot (see Tasks and Operator Chains).


### Tasks and Operator Chains
For distributed execution, Flink chains operator subtasks together into tasks.
Each task is executed by one thread.
Chaining operators together into tasks is a useful optimization: it reduces the overhead of thread-to-thread handover and buffering, and increases overall throughput while decreasing latency. The chaining behavior can be configured; see the chaining docs for details.

The sample dataflow in the figure below is executed with five subtasks, and hence with five parallel threads.

<p align="center">
<img src="https://github.com/rokmc756/Apache-Flink/blob/main/roles/flink/images/apache_flink_tasks_chains.svg" width="80%" height="80%">
</p>


### Task Slots and Resources
Each worker (TaskManager) is a JVM process, and may execute one or more subtasks in separate threads.
To control how many tasks a TaskManager accepts, it has so called task slots (at least one).

Each task slot represents a fixed subset of resources of the TaskManager.
A TaskManager with three slots, for example, will dedicate 1/3 of its managed memory to each slot.
Slotting the resources means that a subtask will not compete with subtasks from other jobs for managed memory,
but instead has a certain amount of reserved managed memory.
Note that no CPU isolation happens here; currently slots only separate the managed memory of tasks.

By adjusting the number of task slots, users can define how subtasks are isolated from each other.
Having one slot per TaskManager means that each task group runs in a separate JVM (which can be started in a separate container, for example).
Having multiple slots means more subtasks share the same JVM.
Tasks in the same JVM share TCP connections (via multiplexing) and heartbeat messages.
They may also share data sets and data structures, thus reducing the per-task overhead.

<p align="center">
<img src="https://github.com/rokmc756/Apache-Flink/blob/main/roles/flink/images/tasks_slots.svg" width="80%" height="80%">
</p>


By default, Flink allows subtasks to share slots even if they are subtasks of different tasks, so long as they are from the same job. The result is that one slot may hold an entire pipeline of the job. Allowing this slot sharing has two main benefits:
A Flink cluster needs exactly as many task slots as the highest parallelism used in the job. No need to calculate how many tasks (with varying parallelism) a program contains in total.
It is easier to get better resource utilization. Without slot sharing, the non-intensive source/map() subtasks would block as many resources as the resource intensive window subtasks. With slot sharing, increasing the base parallelism in our example from two to six yields full utilization of the slotted resources, while making sure that the heavy subtasks are fairly distributed among the TaskManagers.

<p align="center">
<img src="https://github.com/rokmc756/Apache-Flink/blob/main/roles/flink/images/slot_sharing.svg" width="80%" height="80%">
</p>


### Flink Application Execution
A Flink Application is any user program that spawns one or multiple Flink jobs from its main() method.
The execution of these jobs can happen in a local JVM (LocalEnvironment) or on a remote setup of clusters with multiple machines (RemoteEnvironment).
For each program, the ExecutionEnvironment provides methods to control the job execution (e.g. setting the parallelism) and to interact with the outside world (see Anatomy of a Flink Program).
The jobs of a Flink Application can either be submitted to a long-running Flink Session Cluster, a dedicated Flink Job Cluster (deprecated), or a Flink Application Cluster.
The difference between these options is mainly related to the cluster’s lifecycle and to resource isolation guarantees.

## Flink Application Cluster
- **Cluster Lifecycle**: a Flink Application Cluster is a dedicated Flink cluster that only executes jobs from one Flink Application and where the main() method runs on the cluster rather than the client. The job submission is a one-step process: you don’t need to start a Flink cluster first and then submit a job to the existing cluster session; instead, you package your application logic and dependencies into a executable job JAR and the cluster entrypoint (ApplicationClusterEntryPoint) is responsible for calling the main() method to extract the JobGraph. This allows you to deploy a Flink Application like any other application on Kubernetes, for example. The lifetime of a Flink Application Cluster is therefore bound to the lifetime of the Flink Application.
- **Resource Isolation**: in a Flink Application Cluster, the ResourceManager and Dispatcher are scoped to a single Flink Application, which provides a better separation of concerns than the Flink Session Cluster.

## Flink Session Cluster
- **Cluster Lifecycle**: in a Flink Session Cluster, the client connects to a pre-existing, long-running cluster that can accept multiple job submissions. Even after all jobs are finished, the cluster (and the JobManager) will keep running until the session is manually stopped. The lifetime of a Flink Session Cluster is therefore not bound to the lifetime of any Flink Job.
- **Resource Isolation**: TaskManager slots are allocated by the ResourceManager on job submission and released once the job is finished. Because all jobs are sharing the same cluster, there is some competition for cluster resources — like network bandwidth in the submit-job phase. One limitation of this shared setup is that if one TaskManager crashes, then all jobs that have tasks running on this TaskManager will fail; in a similar way, if some fatal error occurs on the JobManager, it will affect all jobs running in the cluster.
- **Other considerations**: having a pre-existing cluster saves a considerable amount of time applying for resources and starting TaskManagers. This is important in scenarios where the execution time of jobs is very short and a high startup time would negatively impact the end-to-end user experience — as is the case with interactive analysis of short queries, where it is desirable that jobs can quickly perform computations using existing resources.



## What is the purpose of  this Ansible Playbook?
It is Ansible Playbook to deploy Apache Flink conveniently on Baremetal, Virtual Machines and Cloud Infrastructure.
The main purpose of this project is actually very simple. Because i have many jobs to install different kind of Apache Flink versions and reproduce issues & test features  as a support
engineer. I just want to spend less time for it.


# Flink Ansible role
![Logo](logo.gif)

[![Build Status](https://app.travis-ci.com/idealista/flink_role.svg)](https://app.travis-ci.com/github/idealista/flink_role)
[![Ansible Galaxy](https://img.shields.io/badge/galaxy-idealista.flink_role-B62682.svg)](https://galaxy.ansible.com/idealista/flink_role)



This ansible role installs Flink in a Debian environment. It has been tested for the following Debian versions:

* Bullseye

This role has been generated using the [cookiecutter](https://github.com/cookiecutter/cookiecutter) tool, you can generate a similar role that fits your needs using the this [cookiecutter template](https://github.com/idealista/cookiecutter-ansible-role).

- [Getting Started](#getting-started)
	- [Prerequisities](#prerequisities)
	- [Installing](#installing)
- [Usage](#usage)
- [Testing](#testing)
- [Built With](#built-with)
- [Versioning](#versioning)
- [Authors](#authors)
- [License](#license)
- [Contributing](#contributing)

## Getting Started
These instructions will get you a copy of the role for your Ansible playbook. Once launched, it will install Flink in a Debian system.

### Prerequisities

Ansible 4.4.0 version installed.

Molecule 3.x.x version installed.

For testing purposes, [Molecule](https://molecule.readthedocs.io/) with [Docker](https://www.docker.com/) as driver and [Goss](https://github.com/aelsabbahy/goss) as verifier.

### Installing

Create or add to your roles dependency file (e.g requirements.yml):

```
- src: idealista.flink_role
  version: 1.0.0
  name: flink_role
```

Install the role with ansible-galaxy command:

```
ansible-galaxy install -p roles -r requirements.yml -f
```

Use in a playbook:

```
---
- hosts: someserver
  roles:
    - role: flink_role
```

## Usage

Look to the [defaults](defaults/main.yml) properties file to see the possible configuration properties, it is very likely that you will not need to override any variables.


## Testing

### Install dependencies

```sh
$ pipenv sync
```

For more information read the [pipenv docs](ipenv-fork.readthedocs.io/en/latest/).

### Testing

```sh
$ pipenv run molecule test 
```

## Built With

![Ansible](https://img.shields.io/badge/ansible-4.4.0-green.svg)
![Molecule](https://img.shields.io/badge/molecule-3.4.0-green.svg)
![Goss](https://img.shields.io/badge/goss-0.3.16-green.svg)

## Versioning

For the versions available, see the [tags on this repository](https://github.com/idealista/flink_role/tags).

Additionaly you can see what change in each version in the [CHANGELOG.md](CHANGELOG.md) file.

## Authors

* **Idealista** - *Work with* - [idealista](https://github.com/idealista)

See also the list of [contributors](https://github.com/idealista/flink_role/contributors) who participated in this project.

## License

![Apache 2.0 License](https://img.shields.io/hexpm/l/plug.svg)

This project is licensed under the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) license - see the [LICENSE](LICENSE) file for details.

## Contributing

Please read [CONTRIBUTING.md](.github/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.


## REferences

https://nightlies.apache.org/flink/flink-docs-release-1.11/ops/deployment/cluster_setup.html
https://medium.com/@mulan101/apache-flink%EB%9E%80-6f5e34ff7ac6
https://digitalbourgeois.tistory.com/184#google_vignette


## Ansible Playbook
- https://github.com/nikosgavalas/ansible-flink/tree/master
- https://github.com/idealista/flink_role

