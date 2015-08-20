package NS::VSSH::OCMD::Help;
use strict;
use warnings;
use Carp;

use NS::Hermes;
use Term::ANSIColor qw(:constants :pushpop );
$Term::ANSIColor::AUTORESET = 1;

our $BTLEN = 30;

my %HELP =
(
    '.add' => '添加机器到当前数据库，支持range表达式，多个range可以同时add进去，用空格分开.
                 --- .add {==foo==*??==*}
                 --- .add : 不加参数,回车后程序在标准输入等待，把机器列表粘贴过来，
                          然后输入"END",回车后列表被导入当前数据库。
                 ',
    '.del' => '在当前空间删除机器列表，格式与 .add 类似.',
    '.sort' => '对当前的机器列表排序
                 --- .sort ：字符排序
                 --- .sort Num : 按照机器列表中的第Num个数字排序',



    '.cleardb' => '清空当前使用的数据库,
                -- .cleardb： 清空当前数据库
                -- .cleardb foo： 清空foo数据库
                -- .cleardb foo bar ： 同时清空foo,bar数据库',

    '.use' => '进入当前使用的:
                ---.use foo: 使用数据库foo
                ---.use bar:1~10,13  :使用bar数据库的1～10和13号机器，
                    这种状态下不允许对数据库进行 add del sort操作


                 vssh最开始登录的时候用的是base数据库，这个数据库是不共享的，
                      不管是否配置了hostdb这个路径.
                  ',


    '.sudo' => '指定sudo的对象
                    --- .sudo : 没有参数默认sudo到root
                    --- .sudo search :sudo到search用户',
    '.unsudo' => '撤销sudo的设置',

    '.list' => '列出当前空间的机器',
    '.dump' => 'dump出当前数据库的机器',
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
    '.expect' => '运行批量命令,与mcmd类似，但是多自动应答
                    .expect ssh -l foo {} ls : 检查当前空间所以的机器的80端口( {} 是一个宏 )',

    '.history' => '显示历史',
    '.clear' => '清屏 （或者Ctrl+l）',
    '.debug' => '调试模式
                     --- .debug : 没有参数，打印出当前vssh对象
                     --- .debug on: 打开调试模式
                     --- .debug off： 关闭调试模式',


    '.config' => '修改ssh的参数，
                      --- .config :展示当前配置信息
                      --- .config max.ssh=128 :把ssh的最大并发数改成128
                      tmppath=/tmp :临时文件存放目录，包括历史命令和ssh产生的临时文件
                      timeout=300  :命令的超时（单位：秒）
                      max.mcmd=128 :运行mcmd时的并发
                      max.rsync=3  :运行rsync时的并发
                      max.ssh=128  :运行ssh时的并发
                      sudo=        :指定的sudo用户
                      sshSafeModel=1 :vssh的模式：sshSafeModel=1 时候表示安全模式，
                                          在非安全模式下只能运行简单的命令，否则会出现错误
                      tty=1        : tty=0 :不需要tty ; tty=1 :使用tty ; tty=2 :强制使用tty
                      quiet=1      : quiet=1 : 安静模式; quiet=0 :实时显示模式

                      askpass.[Pp]assword=PASSWD : 在执行远程命令时和 .rsync同步数据的时候
                                   需要自动应答的情况 "PASSWD"指用户的密码。
                                     如： 在有输出abc的时候应答ok 可以添加配置
                                             askpass.abc=ok
                  ',

    '.help' => 'show help info
                   exit \ quit \ logout \ Ctrl+D : 退出

                ',
);

sub new
{
    my ( $this ) = @_;
    bless +{}, ref $this || $this;
}

sub get
{
    my ( $this, $name ) = @_;
    return $HELP{$name};
}

sub list
{
    return keys %HELP;
}

sub help
{
    my ( $this, $name ) = @_;

    $name = 'help' if $name && ! $HELP{$name};

    my $hp = sub 
    {
        my ( $k, $d ) = @_;
        print BOLD BRIGHT_YELLOW $k;
        print ' ' x ( 12 - length $k );
        my @d = split /\\n/, $d;
        printf "  %s\n", shift @d if @d;
        map{print ' ' x 16 , $_, "\n"}@d;
    };
    my $mhp = sub
    {
        map{ &$hp( $_, $HELP{$_}) }@_;
        print "\n";
    };
    my $title = sub
    {
        my $t = shift;
        my $l = int (( 50 - length $t ) / 2);
        my $r = 50 - $l - length $t;
        print '*' x $l , " $t ", '*' x $r, "\n";
    }; 

    if( $name )
    {
        &$mhp( '.'. $name );
        return $this;
    }
   
    map{ &$hp( $_, $HELP{$_}) }qw( .help );
   
    &$title( 'host Ctrl' );
    &$mhp( qw( .add .del .sort ) );

    &$title( 'Host DB' );
    &$mhp( qw( .use .cleardb ) );

    &$title( 'Config' );
    &$mhp( qw( .config .sudo .unsudo ) );

    &$title( 'show info' );
    &$mhp( qw( .list .dump  .info ));


    &$title( 'local cmd' );
    &$mhp( qw( .rsync .mcmd .expect ));

    &$title( 'term' );
    &$mhp( qw( .history .clear ));
}


sub welcome
{
printf <<EOF;
                        _                          
          __      _____| | ___ ___  _ __ ___   ___ 
          \\ \\ /\\ / / _ \\ |/ __/ _ \\| '_ ` _ \\ / _ \
           \\ V  V /  __/ | (_| (_) | | | | | |  __/
            \\_/\\_/ \\___|_|\\___\\___/|_| |_| |_|\\___|
          
EOF

}

sub yesno
{
    while( 1 )
    {
        print "Are you sure you want to run this command [y/n]:";
        my $in = <STDIN>;
        next unless $in;
        return 1 if $in eq "y\n";
        return 0 if $in eq "n\n";
    }
}

sub head
{
    my ( $this, $name ) = @_;
    $name = 'help' if $name && ! $HELP{$name};
    print PUSHCOLOR RED ON_GREEN  "#" x $BTLEN, " $name ", "#" x $BTLEN;
    print "\n";
    return $this;
}

sub tail
{
    my ( $this, $name ) = @_;
    $name = 'help' if $name && ! $HELP{$name};
    print PUSHCOLOR RED ON_GREEN  "-" x ( $BTLEN * 2 + 2  + length $name );
    print "\n";
    return $this;
}

sub result
{
    my ( $this, %re ) = @_;

    print "\n";
    print PUSHCOLOR RED ON_GREEN  "#" x $BTLEN, ' RESULT ', "#" x $BTLEN;
    print "\n";

    my $range = NS::Hermes->new( );
    print "=" x 68, "\n";
    map{

        my $c = YAML::XS::Load $_;
        printf "%s[", $range->load( $re{$_} )->dump;
        my $count = scalar @{$re{$_}};
        $c->{'exit'} ? print BOLD  RED $count : print BOLD GREEN $count;

        print "]:\n";
        print BOLD  GREEN "$c->{stdout}\n" if $c->{stdout};
        print BOLD  RED   "$c->{stderr}\n" if $c->{stderr};
        print "=" x 68, "\n";
    }keys %re;
}

1;
