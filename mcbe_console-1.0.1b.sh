#!/bin/bash
function pause ()
{
	echo '请按任意键继续...'
	read -n 1 -p "$*" pause_input
	if [ -z "$pause_input" ];then
		pause_input=1
	fi
	if [ $pause_input != '' ] ; then
		echo -ne '\b \n'
	fi
}
function check ()
{
	memory=$(ls /run/screen/S-mcbe/*.mcbe 2>/dev/null)
	if [ ! -n "$memory" ];then
		if [ "$1" != "n" ];then
			echo "mcbe服务器未启动。"
		fi
		return 1
	else
		if [ "$1" != "n" ];then
			echo "mcbe服务器已经在后台运行。"
		fi
		return 0
	fi
}
function askyn ()
{
	local answer=0
	while [ $answer == 0 ];do
		read -p $1"[Y/n]：" input
		case $input in
			[Yy])
				return 1
			;;
			[Nn])
				return 0
		esac
	done
}
function run ()
{
	screen -dmS mcbe
	screen -S mcbe -X stuff "cd server \n"
	screen -S mcbe -X stuff 'LD_LIBRARY_PATH=. ./bedrock_server'
	screen -S mcbe -X stuff '\n'
	#回车部分单引号或双引号均可
	screen -r mcbe
	status_change=1
}
function stop ()
{
	if check;then
		screen -S mcbe -X stuff "stop"
		screen -S mcbe -X stuff "\n"
		screen -S mcbe -X quit
		echo "关闭mcbe服务器完成。"
		status_change=1
	fi
}
function start ()
{
	if check;then
		reboot_stop_answer=0
		while [ $reboot_stop_answer == 0 ];do
			echo "是要重启mcbe服务器还是要关闭mcbe服务器？"
			read -p "[R-重启服务器，S-关闭服务器，C-取消且不进行任何操作]：" reboot_stop
			case $reboot_stop in
				[Rr])
					reboot_stop_answer=1
					stop
					run
				;;
				[Ss])
					reboot_stop_answer=1
					stop
				;;
				[Cc])
					reboot_stop_answer=1
			esac
		done
	else
		if askyn "确定要启动服务器吗？";then
			exit
		else
			run
		fi
	fi
}
function backup ()
{
	if [ ! -d backup ];then
		mkdir backup
	fi
	read -p "请输入要备份的存档编号（推荐使用日期）：" b_num
	if [ -d backup/$b_num ];then
		exist=1
		while [ $exist == 1 ];do
			echo "该存档目录已经存在！"
			read -p "您希望覆盖旧的存档吗？[Y/n]" cover
			case $cover in
				[Yy])
					echo "正在删除旧的存档..."
					rm -r backup/$b_num
					exist=0
				;;
				[Nn])
					read -p "请重新输入要备份的存档编号（推荐使用日期）：" b_num
					if [ ! -d backup/$b_num ];then
						exist=0
					fi
			esac
		done
	fi
	echo "正在备份存档...（编号为"$b_num"）"
	mkdir backup/$b_num
	cp -p server/permissions.json backup/$b_num
	cp -p server/server.properties backup/$b_num
	if [ -d server/worlds ];then
		cp -p -r server/worlds backup/$b_num
	else
		echo "未找到worlds,因此仅备份了基本配置"
	fi
	echo "备份存档完成。"
}
function recovery ()
{
	read -p "请输入要恢复的存档编号（推荐使用日期）：" r_num
	while [ ! -d backup/$r_num ];do
		echo "该存档目录不存在！"
		read -p "请重新输入要恢复的存档编号（推荐使用日期）：" r_num
	done
	echo "正在检查存档完整性..."
	pass=1
	if [ ! -f backup/$r_num/permissions.json ];then
		echo "缺少permissions.json"
		pass=0
	fi
	if [ ! -f backup/$r_num/server.properties ];then
		echo "缺少server.properties"
		pass=0
	fi
	if [ ! -d backup/$r_num/worlds ];then
		echo "该存档缺少worlds，可能为基本配置的存档"
	fi
	if [ $pass == 1 ];then
		echo "检查完毕，正常。"
		cp -p backup/$r_num/permissions.json server/
		cp -p backup/$r_num/server.properties server/
		cp -p -r backup/$r_num/worlds server/
		echo "恢复存档完成。"
	else
		echo "该存档可能已损坏！"
	fi
}
function update ()
{
	if askyn "升级mcbe服务器前需要停止服务器并备份存档！确定继续吗？";then
		echo "中止。"
	else
		echo "正在停止mcbe服务器并备份存档..."
		stop
		if askyn "要备份存档吗？";then
			echo "未备份存档。"
		else
			backup
		fi
		#升级开始
		if [ -d server ];then
			rm -r server
		fi
		mkdir server
		echo "删除旧版mcbe服务器完成。"
		read -p "输入最新版本mcbe服务器的下载链接：" link
		echo 正在下载$link至cache下
		if [ -d cache ];then
			rm -r cache
		fi
		mkdir cache
		wget $link -P cache
		zip=${link##*/}
		echo $zip"下载完成，正在解压缩..."
		unzip -q -d server/ cache/$zip
		ver_zip=${zip##*-}
		version=${ver_zip%.*}
		echo $version > server/ver.txt
		echo "新版mcbe服务器安装完成。"
		#升级结束
		if askyn "是否立即恢复存档？";then
			echo "你可以稍后恢复存档或建立新存档。"
		else
			recovery
		fi
		if askyn "是否保留下载的zip（至zip文件夹）？";then
			echo "cache文件夹下的zip文件将会被清除。"
		else
			if [ ! -d zip ];then
				mkdir zip
			fi
			cp cache/$zip zip
		fi
		rm -r cache
		echo "清除cache完成。"
		echo "结束。"
	fi
}
ls -l backup |awk '/^d/ {print $NF}'
function main ()
{
	if [ "$1" == "c" ];then
		clear
	fi
	echo "|Minecraft:Bedrock Edition Server Console|"
	echo "|Author: ZYL456|"
	echo "[1]升级或安装服务器"
	echo "[2]启动服务器"
	echo "[3]关闭服务器"
	echo "[4]查看现有存档"
	echo "[5]备份服务器"
	echo "[6]恢复服务器"
	echo "[7]设置"
	echo "[8]关于"
	echo "[E]退出控制台"
	if check n;then
			status="开启"
		else
			status="关闭"
	fi
	if [ -f server/ver.txt ];then
		read version < server/ver.txt
	else
		version="未知"
	fi
	echo "|服务器状态："$status"|服务器版本："$version"|控制台版本：1.0.0a|"
	echo "|Github:https://github.com/zyl456/MCBE_Server_Console|"
	tuichu=0
	while [ $tuichu == 0 ];do
		status_change=0
		read -p ">" option
		case $option in
			[1])
				update
			;;
                        [2])
                                start
                        ;;
                        [3])
                                stop
                        ;;
			[4])
				ls -l backup |awk '/^d/ {print $NF}'
			;;
			[5])
				if [ $status == "开启" ];then
					backup_answer=0
					while [ $backup_answer == 0 ];do
						echo "mcbe服务器正在运行，此时备份存档小概率会导致存档损坏，最好在服务器内没有玩家的情况下进行，你想要怎么做？"
						read -p "[R-关闭服务器并备份，I-直接备份，C-取消且不进行任何操作]：" reboot_stop
						case $reboot_stop in
							[Rr])
								backup_answer=1
								stop
								backup
							;;
							[Ii])
								backup_answer=1
								backup
							;;
							[Cc])
								backup_answer=1
						esac
					done
				else
					backup
				fi
			;;
			[6])
				if [ $status == "开启" ];then
					if askyn "mcbe服务器正在运行，必须在服务器关闭的情况下才能恢复存档！确定要关闭服务器并恢复存档吗？";then
						echo "请在服务器关闭的情况下恢复存档。"
					else
						stop
						recovery
					fi
				else
					recovery
				fi
			;;
			[7])
				echo "当前版本无设置，你可以前往Github查看最新进展。"
			;;
			[8])
				echo "Minecraft:Bedrock Edition Server Console "
				echo "version：1.0.0a"
				echo "Author：ZYL456"
				echo "Github项目：https://github.com/zyl456/MCBE_Server_Console"
				pause
			;;
			[9Ee])
				tuichu=1
				exit
		esac
		if [ $status_change == 1 ];then
			main
		fi
	done
}
main c
