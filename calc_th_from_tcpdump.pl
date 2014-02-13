#!/usr/bin/perl

# サーバ側ログファイル（受信データ）を入力ファイルとする

# 各ノードで1秒ごとの
# ・合計受信スループットを全区間平均して出力 単位はkbit/sec

# 試行回数

if ( scalar(@ARGV)<1 || scalar(@ARGV)>1 ) {
    die "<Usage>: perl calc_th_pernode_from_imagerecvlog.pl (logfile_received_imagedata) .\nEXIT... \n";
}
#何秒間の平均スループットを取るかというパラメータ
$one_segment = 10;

#入力ファイル数はワイルドカードなどで何個でも指定可能とする


foreach $file (@ARGV) {
    #ハッシュの初期化 
    # (ip address)('time_first_recv') 初回データ受信時刻
    # (ip address)('time_last_recv')  最後のデータの受信時刻
    # (ip address)('amount_data')     合計受信データ量
    %hash_addr = ();

    open IN, $file or die "cannot open $file ($!)";
    chomp(@line = <IN>);
    
    $isTimeFirst = 1;
    $first = 0;

    foreach (@line) {
	@fields              = split(/ +/, $_);
	#送信元IPアドレス
	$ipaddr              = "$fields[5]";
	#受信時刻
	@time_field          = split(/:/, $fields[0]);
	$time = $time_field[0]*3600+$time_field[1]*60+$time_field[2];

	#送信データサイズ
	$datasize_onesegment =  $fields[7];


	#ハッシュから該当IPアドレスの項目の有無を調べる
	if ( scalar(%hash_addr) == 0) { #ハッシュ自体が空
	    $ip_in_hash = 0;
	} else {
	    if (defined($hash_addr{$ipaddr})) { #ハッシュの中にip発見
		$ip_in_hash = 1;
	    } else { #ハッシュの中に該当ipなし
		$ip_in_hash = 0;
	    }
	}
	#この場合ip_in_hashはいらなかったかも

	if ($isTimeFirst ==1) { #ログの最初の行の時間から１秒ずつスループットを算出する
	    $time_segment_first     = $time;
	    $segment                = 1;
	    $isTimeFirst            = 0;
	}
	
	
	#one_segment時間経ったらすべてのノードにおいてスループット算出
	if($time - $time_segment_first >= $one_segment) {

	    foreach $key_ipaddr ( sort keys %hash_addr) {
		$hash_addr{$key_ipaddr}{'th'}{$segment} 
		= ($hash_addr{$key_ipaddr}{'data_size_one_sec'}*8.0)/($one_segment*1000); #1秒の合計受信データ量
		# printf("%d,ip %s,segment %d, th,%.3lf,kbits/sec\n"
		#        ,$time_segment_first
		#        ,$key_ipaddr
		#        ,$segment
		#        ,$hash_addr{$key_ipaddr}{'th'} {$segment} );
		$hash_addr{$key_ipaddr}{'data_size_one_sec'}  = 0; #初期化
		
	    }
	    $time_segment_first = $time;
	    $segment++;
	    
	}
	$hash_addr{$ipaddr}{'data_size_one_sec'}  += $datasize_onesegment;
	
	# printf("ip %s,segment %d, amount,%d\n"
	#        ,$ipaddr
	#        ,$hash_addr{$ipaddr}{'segment'}
	#        ,$hash_addr{$ipaddr}{'data_size_one_sec'});
    }
    
#一番最後のセグメントについては、スループット算出前にループを抜けている場合があるので
#ここで算出
    foreach $key_ipaddr ( sort keys %hash_addr) {
	$hash_addr{$key_ipaddr}{'th'}{$segment} 
	= ($hash_addr{$key_ipaddr}{'data_size_one_sec'}*8.0)/(($time - $time_segment_first)*1000); #1秒の合計受信データ量
	# printf("%d,ip %s,segment %d, th,%.3lf,kbits/sec\n"
	#        ,$time_segment_first
	#        ,$key_ipaddr
	#        ,$segment
	#        ,$hash_addr{$key_ipaddr}{'th'} {$segment} );
	$hash_addr{$key_ipaddr}{'data_size_one_sec'}  = 0; #初期化
	
    }

    #各IPアドレスごとに合計受信データ量をまとめる
    if ( scalar(%hash_addr) == 0) { #ハッシュ自体が空
	printf("No data received\n");
    } else {

	#ipアドレス出力
	foreach $key_ipaddr ( sort keys %hash_addr) {
	    printf("%s,",${key_ipaddr});
	    
	}
	printf("\n");
	$max_segment = $segment;
	#ノードIP毎に各秒での受信スループットを算出
	for($segment = 1; $segment <= $max_segment; $segment++) {
	    printf("%d,",$segment);
	    foreach $key_ipaddr ( sort keys %hash_addr) {
		
		printf("%.3lf,kbps,",
		       $hash_addr{$key_ipaddr}{'th'}{$segment} );
	    }
	    printf("\n");
	}
    }
}

exit;
