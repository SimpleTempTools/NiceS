                         NiceS 平台说明


NiceS运维平台集成了:项目管理、程序发布、监控、工具集。

==================================概览======================================

    在ns目录下归类放了按照功能分割的功能集。在每个目录下通常会出现的子目录
有bin、conf、code、lib、service。
      bin：  可用的工具
      conf： 和子平台相关的配置文件
      code： 插件代码
      lib：  因具体环境而编写的perl模块，平台抽象的模块放perl的标准lib目录下
      service：子平台中需要一直在后台服务的程序

    ns的总配置 ns/.config ,是一个yaml格式的文件，每一个key对应一个子平台，该
文件如果出错将导致整个平台读取配置失败。


    子平台简介：

        apps: 对服务操作统一接口和包管理
        argos：监控平台
        collector：运行在被监控机器上的信息采集客户端
        cronos：排班系统
        daemon：守护进程管理
        deploy：发布系统
        hermes：操作对象管理平台
        monitor: 监控信息汇集
        notify：报警出口，组管理
        poros：远程调用，所有服务器上都运行有agent，用于控制机器
        recorder: opsdb的服务端
        register：opsdb的客户端
        rrd：rrd数据存储平台
        tools： 工具集
        util：缺省的或者ns平台通用的服务、配置、lib
        web：ns的web端
        zks: 连接zookeeper在web端展示状态


===================================安装=====================================

    安装步骤：
        1: /path/to/your/perl Makefile.PL
        2: make
        3: make install nices=/path/to/ns  #指定工具集安装的目录，如不指定则
           不安装工具, 在指定nices的同时可以通过conf指定配置，在conf目录中按
           照实际应用场景对配置进行了分类，如在 conf 中存在配置nices，
           则可以通过 make install nices=/path/to/ns conf=nices 在安装工具的
           同时指定nices选择的配置
