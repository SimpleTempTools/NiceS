package NS::VSSH::Constants;

use strict;
use warnings;
use Carp;

our $BTLEN = 30;

our %HELP = 
(
    '.add' => '添加机器到当前的名字空间，支持range表达式，多个range可以同时add进去，用空格分开.
                 --- .add {%%seco} {==*==*??==*}',
    '.del' => '在当前空间删除机器列表，格式与 .add 类似.',
    '.load' => 'load 机器列表到当前空间（load的内容保持顺序）.
                 --- .load : 读取输入的内容（可以换行，输入结束标识符为‘END’）
                 --- .load file: 读取file的内容',
    '.sort' => '对当前的机器列表排序
                 --- .sort ：字符排序
                 --- .sort Num : 按照机器列表中的第Num个数字排序',
    '.block' => '剔除部分机器而不删除
                 --- .block i0{1~9}.se.bjdt.nices.net : 在当前空间剔除9台机器（如果存在的话）
                 --- .block *i0{1~3}.se.bjdt.nices.net : 强制锁定这3太机器
                 --- .block clear: 清除这个空间的block',
  
    '.filter' => '机器列表过滤器
                --- .filter /shjc/: 把包含shjc字符的机器过来出来
                --- .filter -/shjc/: 把包含shjc字符的机器去掉', 


    '.use' => '进入一个名字空间:
                ---.use: 进入缺省空间base
                ---.use test: 进入test空间',

    '.save' => '保存机器列表到空间:
                --- .save 保存当前空间的机器到缺省空间base
                --- .save test: 保存机器到空间test
                --- .save test 1 2 40%: 保存机器到test的分空间，相当于把机器列表切分',
    '.tmp' => '进入一个临时的空间tmp，每次进入都会清空机器列表（如不想情况可以用 .use tmp 进入）',
    '.clearspace' => '清空当前空间的机器和block
                -- .clearspace： 清空当前空间
                -- .clearspace foo bar： 清空空间foo和bar
                -- .clearspace *： 清空所有空间',


    '.sudo' => '指定sudo的对象',
    '.unsudo' => '撤销sudo的设置',
    '.user' => '切换新用户： .user username',
    '.password' => '重新登记密码',


    '.tty ON|OFF' => 'ssh的pty开关',
    '.timeout' => '远程命令的超时时间',
    '.max' => '并发数量（不做用于rsync）,如果设置成1时，相当于串行运行',
    '.quiet' => '不显示运行过程的输出，只显示汇总信息',
    '.verbose' => '显示运行过程的信息',

    '.list' => '列出当前空间的机器',
    '.dump' => 'dump出当前空间的机器',
    '.info' => '展示一下详细信息',


    '.rsync' => '在本地同步数据到远程机器上
                    .rsync [本地目录] [远程目录(缺省时和本地目录一样)] [rsync 参数]
                    ---.rsync /tmp/foo：同步/tmp/foo目录到远程机器
                    ---.rsync /tmp/bar/ -av --delete 同步/tmp/bar/目录，
                            指定rsync参数 --av --delete
                    ---.rsync /tmp/foo /tmp/bar :同步本地/tmp/foo 到远程的/tmp/bar
    ',
    '.mcmd' => '运行批量命令
                    .mcmd nc -z {} 80 : 检查当前空间所以的机器的80端口( {} 是一个宏 )',
    '.local' => '运行本地命令',

    '.history' => '显示历史',
    '.lock' => '锁住当前shell',
    '.clear' => '清屏 （或者Ctrl+l）',

    '.help' => 'show help info',
);

our $WELCOME = sprintf <<EOF;
                        _                          
          __      _____| | ___ ___  _ __ ___   ___ 
          \\ \\ /\\ / / _ \\ |/ __/ _ \\| '_ ` _ \\ / _ \
           \\ V  V /  __/ | (_| (_) | | | | | |  __/
            \\_/\\_/ \\___|_|\\___\\___/|_| |_| |_|\\___|
          
EOF

1;
