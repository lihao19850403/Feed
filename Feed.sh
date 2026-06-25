#!/bin/bash

# 控制台版Todo日历。请先填写任务单所在目录路径。

TASKS_PATH=""

# 一些常量。

HIGH_LIGHT_COLOR="\e[96m"
YELLOW_COLOR="\e[33m"
NORMAL_COLOR="\e[37m"

WEEK_DAY_NAMES=("日" "一" "二" "三" "四" "五" "六")
NORMAL_MONTH_DAYS=(31 28 31 30 31 30 31 31 30 31 30 31)
LEAP_MONTH_DAYS=(31 29 31 30 31 30 31 31 30 31 30 31)

MIN_YEAR=1900
MAX_YEAR=2200

# 当前日期信息。

CURRENT_YEAR=$(date "+%Y")
CURRENT_MONTH=$(date "+%m")
if [ "${CURRENT_MONTH:0:1}" -eq "0" ]; then
  CURRENT_MONTH=${CURRENT_MONTH:1:1}
fi
CURRENT_DAY=$(date "+%d")
if [ "${CURRENT_DAY:0:1}" -eq "0" ]; then
  CURRENT_DAY=${CURRENT_DAY:1:1}
fi
CURRENT_WEEK_DAY_INDEX=$(date -j -f "%Y-%m-%d" "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}" "+%u")
if [ "${CURRENT_WEEK_DAY_INDEX}" -eq "7" ]; then
  CURRENT_WEEK_DAY_INDEX=0
fi

# 一些计算结果。

SPECIAL_INTRODUCTION=""
CURRENT_SPECIAL_TASKS=()
CURRENT_SPECIAL_TASKS_LENGTH=()

TASKS_INTRODUCTION=""
CURRENT_MONTH_TASKS=()
CURRENT_MONTH_TASKS_LENGTH=()

# 记录本次输出了多少行，用于屏幕刷新。

CURRENT_OUTPUT_LINES_COUNT=0
SPECIAL_LINES_COUNT=0
TASKS_LINES_COUNT=0

# 重置计算结果。
function resetResults() {
  SPECIAL_INTRODUCTION=""
  CURRENT_SPECIAL_TASKS=()
  CURRENT_SPECIAL_TASKS_LENGTH=()
  TASKS_INTRODUCTION=""
  CURRENT_MONTH_TASKS=()
  CURRENT_MONTH_TASKS_LENGTH=()
  CURRENT_OUTPUT_LINES_COUNT=0
  SPECIAL_LINES_COUNT=0
  TASKS_LINES_COUNT=0
}

# 判断是否闰年。返回值0表示不是闰年，返回值1表示是闰年。
function checkIfLeapYear() {
  year=${1}
  result=0
  if [ $((year % 4)) -eq 0 ] && [ $((year % 100)) -ne 0 ]; then
    result=1
  elif [ $((year % 400)) -eq 0 ]; then
    result=1
  elif [ $((year % 3200)) -eq 0 ] && [ $((year % 172800)) -eq 0 ]; then
    result=1
  else
    result=0
  fi
  return ${result}
}

# 检查日期的合法性。返回值0表示不合法，返回值1表示合法。
function checkIfDateValid() {
  if [ $((CURRENT_YEAR)) -lt $((MIN_YEAR)) ] || [ $((CURRENT_YEAR)) -gt $((MAX_YEAR)) ]; then
    return 0
  fi
  if [ $((CURRENT_MONTH)) -lt 1 ] || [ $((CURRENT_MONTH)) -gt 12 ]; then
    return 0
  fi
  thisMonthDays=${1}
  if [ $((CURRENT_DAY)) -lt 1 ] || [ $((CURRENT_DAY)) -gt $((thisMonthDays)) ]; then
    return 0
  fi
  return 1
}

# 解析Todo事件。
function parseTasks() {
  fileArray=$(ls "$1")
  for element in $fileArray; do
    file="${1}""/""${element}"
    if [ -d "$file" ]; then
      parseTasks "$file"
    else
      shopt -s nullglob
      jsonText=$(cat "$file")
      # 解析startTime。
      startTimeValue=${jsonText#*\"startTime\"}
      startTimeValue=${startTimeValue#*\"}
      startTimeValue=${startTimeValue%%\"*}
      startYear=${startTimeValue:0:4}
      if [ $((startYear)) -gt $((CURRENT_YEAR)) ]; then
        continue
      fi
      startMonth=${startTimeValue:4:2}
      if [ "${startMonth:0:1}" -eq "0" ]; then
        startMonth=${startMonth:1:1}
      fi
      if [ $((startYear)) -eq $((CURRENT_YEAR)) ] && [ $((startMonth)) -gt $((CURRENT_MONTH)) ]; then
        continue
      fi
      startDay=${startTimeValue:6:2}
      if [ "${startDay:0:1}" -eq "0" ]; then
        startDay=${startDay:1:1}
      fi
      # 解析endTime。
      endTimeValue=${jsonText#*\"endTime\"}
      endTimeValue=${endTimeValue#*\"}
      endTimeValue=${endTimeValue%%\"*}
      if [ $((endTimeValue)) -eq 0 ]; then
        endTimeValue="${MAX_YEAR}1231"
      fi
      endYear=${endTimeValue:0:4}
      if [ $((endYear)) -lt $((startYear)) ] || [ $((endYear)) -lt $((CURRENT_YEAR)) ]; then
        continue
      fi
      endMonth=${endTimeValue:4:2}
      if [ "${endMonth:0:1}" -eq "0" ]; then
        endMonth=${endMonth:1:1}
      fi
      if [ $((endYear)) -eq $((startYear)) ]; then
        if [ $((endMonth)) -lt $((startMonth)) ] || [ $((endMonth)) -lt $((CURRENT_MONTH)) ]; then
          continue
        fi
      fi
      endDay=${endTimeValue:6:2}
	    if [ "${endDay:0:1}" -eq "0" ]; then
        endDay=${endDay:1:1}
      fi
      if [ $((endYear)) -eq $((startYear)) ] && [ $((endMonth)) -eq $((startMonth)) ]; then
        if [ $((endDay)) -lt $((startDay)) ]; then
          continue
        fi
      fi
      # 解析intervalDays。
      intervalDaysValue=${jsonText#*\"intervalDays\"}
      intervalDaysValue=${intervalDaysValue#*\"}
      intervalDaysValue=${intervalDaysValue%%\"*}
      if [ $((intervalDaysValue)) -eq 0 ]; then
        intervalDaysValue="0"
      fi
      # 解析name。
      nameValue=${jsonText#*\"name\"}
      nameValue=${nameValue#*\"}
      nameValue=${nameValue%%\"*}
      # 解析description。
      descriptionValue=${jsonText#*\"description\"}
      descriptionValue=${descriptionValue#*\"}
      descriptionValue=${descriptionValue%%\"*}
      # 解析icon。
      iconValue=${jsonText#*\"icon\"}
      iconValue=${iconValue#*\"}
      iconValue=${iconValue%%\"*}
      # 解析special。
      specialValue=${jsonText#*\"special\"}
      specialValue=${specialValue#*\"}
      specialValue=${specialValue%%\"*}
      if [ "$specialValue" = "true" ]; then
        # 构造特殊事件介绍。
        if [[ $SPECIAL_INTRODUCTION != *$iconValue* ]]; then
          SPECIAL_INTRODUCTION="$SPECIAL_INTRODUCTION"" $iconValue\t$descriptionValue\n"
          ((SPECIAL_LINES_COUNT+=1))
        fi
      else
        # 构造Todo任务介绍。
        if [[ $TASKS_INTRODUCTION != *$iconValue* ]]; then
          TASKS_INTRODUCTION="$TASKS_INTRODUCTION"" $iconValue\t$descriptionValue\n"
          ((TASKS_LINES_COUNT+=1))
        fi
      fi
      # 计算事件在日历中的显示情况。
      startTimeSeconds=$(date -j -f "%Y%m%d" "${startTimeValue}" "+%s")
      endTimeSeconds=$(date -j -f "%Y%m%d" "${endTimeValue}" "+%s")
      for ((index=0;;)); do
        nextTaskSeconds=$((startTimeSeconds + 86400 * index))
        index=$((index + intervalDaysValue))
        if [ $((nextTaskSeconds)) -gt $((endTimeSeconds)) ]; then
          break
        fi
        nextTaskValue=$(date -j -f "%s" "${nextTaskSeconds}" "+%Y%m%d")
        nextTaskYear=${nextTaskValue:0:4}
        if [ $((nextTaskYear)) -gt $((CURRENT_YEAR)) ]; then
          break
        fi
        nextTaskMonth=${nextTaskValue:4:2}
		    if [ "${nextTaskMonth:0:1}" -eq "0" ]; then
          nextTaskMonth=${nextTaskMonth:1:1}
        fi
        if [ $((nextTaskYear)) -eq $((CURRENT_YEAR)) ]; then
          if [ $((nextTaskMonth)) -gt $((CURRENT_MONTH)) ]; then
            break
          fi
          if [ $((nextTaskMonth)) -eq $((CURRENT_MONTH)) ]; then
            nextTaskDay=${nextTaskValue:6:2}
            if [ "${nextTaskDay:0:1}" -eq "0" ]; then
              nextTaskDay=${nextTaskDay:1:1}
            fi
            nextTaskDayIndex=$((nextTaskDay - 1))
            newIconLength=${#iconValue}
            if [ $((newIconLength % 2)) -ne 0 ]; then
              newIconLength=$((newIconLength + 1))
            fi
            if [ "$specialValue" = "true" ]; then
              oldTask=${CURRENT_SPECIAL_TASKS[nextTaskDayIndex]}
              oldTasksLength=$((CURRENT_SPECIAL_TASKS_LENGTH[nextTaskDayIndex]))
              CURRENT_SPECIAL_TASKS[nextTaskDayIndex]="$oldTask""$iconValue"
              CURRENT_SPECIAL_TASKS_LENGTH[nextTaskDayIndex]=$((oldTasksLength + newIconLength))
            else
              oldTask=${CURRENT_MONTH_TASKS[nextTaskDayIndex]}
              oldTasksLength=$((CURRENT_MONTH_TASKS_LENGTH[nextTaskDayIndex]))
              CURRENT_MONTH_TASKS[nextTaskDayIndex]="$oldTask""$iconValue"
              CURRENT_MONTH_TASKS_LENGTH[nextTaskDayIndex]=$((oldTasksLength + newIconLength))
            fi
          fi
        fi
        if [ $((intervalDaysValue)) -eq 0 ]; then
          break
        fi
      done
    fi
  done
}

# 执行。
function run() {
  # 获取本月一共多少天。
  checkIfLeapYear $((CURRENT_YEAR))
  isLeapYear=$?
  thisMonthDays=${NORMAL_MONTH_DAYS[CURRENT_MONTH-1]}
  if [ $((isLeapYear)) -eq 1 ]; then
    thisMonthDays=${LEAP_MONTH_DAYS[CURRENT_MONTH-1]}
  fi
  for ((index=0;index<thisMonthDays;index++)); do
    CURRENT_MONTH_TASKS[index]=""
    CURRENT_MONTH_TASKS_LENGTH[index]=0
  done

  # 获取本月1日是星期几。0表示星期日。
  firstWeekIndex=$((CURRENT_DAY % 7))
  firstWeekIndex=$(((CURRENT_WEEK_DAY_INDEX - firstWeekIndex + 8) % 7))

  # 获取本月最后一天是星期几。0表示星期日。
  lastWeekIndex=$((thisMonthDays % 7))
  lastWeekIndex=$(((firstWeekIndex + lastWeekIndex + 6) % 7))

  # 构造完整月信息。
  thisMonthDayArr=()
  preEmptyDaysCount=$((firstWeekIndex - 1))
  lastEmptyDaysCount=$((7 - lastWeekIndex))
  if [ $((firstWeekIndex)) -eq 0 ]; then
    preEmptyDaysCount=6
  fi
  if [ $((lastWeekIndex)) -eq 0 ]; then
    lastEmptyDaysCount=0
  fi
  for ((preIndex=0;;preIndex++)); do
    if [ $preIndex -eq $preEmptyDaysCount ]; then
      break
    fi
    thisMonthDayArr[preIndex]=0
  done
  for ((index=0;;index++)); do
    if [ $index -eq "$thisMonthDays" ]; then
      break
    fi
    thisMonthDayArr[index + preEmptyDaysCount]=$((index + 1))
  done
  for ((lastIndex=0;;lastIndex++)); do
    if [ $lastIndex -eq $lastEmptyDaysCount ]; then
      break
    fi
    thisMonthDayArr[lastIndex + preEmptyDaysCount + thisMonthDays]=0
  done

  # 解析Todo事件。
  parseTasks "$TASKS_PATH"

  #########
  # PRINT #
  #########

  # 日期提醒。
  checkIfDateValid $((thisMonthDays))
  isDateValid=$?
  if [ $((isDateValid)) -eq 1 ]; then
    printf "%s""$NORMAL_COLOR";printf " 今天是 "
    printf "%s""$HIGH_LIGHT_COLOR";printf "%s""${CURRENT_YEAR}年${CURRENT_MONTH}月${CURRENT_DAY}日 星期${WEEK_DAY_NAMES[CURRENT_WEEK_DAY_INDEX]}"
  else
    printf "%s""$NORMAL_COLOR";printf " 日期并不存在："
    printf "%s""$HIGH_LIGHT_COLOR";printf "%s""${CURRENT_YEAR}年${CURRENT_MONTH}月${CURRENT_DAY}日"
  fi
  printf "%s""$NORMAL_COLOR";printf "\n"
  ((CURRENT_OUTPUT_LINES_COUNT+=1))

  # 日历头部。
  printf "%s""$NORMAL_COLOR";printf "━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━\n"
  if [ $((CURRENT_WEEK_DAY_INDEX)) -eq 1 ]; then printf "%s""$HIGH_LIGHT_COLOR"; else printf "%s""$NORMAL_COLOR"; fi;printf "%-10s" "    一    ";printf "%s""$NORMAL_COLOR";printf "┃"
  if [ $((CURRENT_WEEK_DAY_INDEX)) -eq 2 ]; then printf "%s""$HIGH_LIGHT_COLOR"; else printf "%s""$NORMAL_COLOR"; fi;printf "%-10s" "    二    ";printf "%s""$NORMAL_COLOR";printf "┃"
  if [ $((CURRENT_WEEK_DAY_INDEX)) -eq 3 ]; then printf "%s""$HIGH_LIGHT_COLOR"; else printf "%s""$NORMAL_COLOR"; fi;printf "%-10s" "    三    ";printf "%s""$NORMAL_COLOR";printf "┃"
  if [ $((CURRENT_WEEK_DAY_INDEX)) -eq 4 ]; then printf "%s""$HIGH_LIGHT_COLOR"; else printf "%s""$NORMAL_COLOR"; fi;printf "%-10s" "    四    ";printf "%s""$NORMAL_COLOR";printf "┃"
  if [ $((CURRENT_WEEK_DAY_INDEX)) -eq 5 ]; then printf "%s""$HIGH_LIGHT_COLOR"; else printf "%s""$NORMAL_COLOR"; fi;printf "%-10s" "    五    ";printf "%s""$NORMAL_COLOR";printf "┃"
  if [ $((CURRENT_WEEK_DAY_INDEX)) -eq 6 ]; then printf "%s""$HIGH_LIGHT_COLOR"; else printf "%s""$YELLOW_COLOR"; fi;printf "%-10s" "    六    ";printf "%s""$NORMAL_COLOR";printf "┃"
  if [ $((CURRENT_WEEK_DAY_INDEX)) -eq 0 ]; then printf "%s""$HIGH_LIGHT_COLOR"; else printf "%s""$YELLOW_COLOR"; fi;printf "%-10s" "    日    ";printf "%s""$NORMAL_COLOR";printf "\n"
  printf "%s""$NORMAL_COLOR";printf "━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━\n"
  ((CURRENT_OUTPUT_LINES_COUNT+=3))

  # 日历本体。
  totalDays=${#thisMonthDayArr[*]}
  linesCount=$((totalDays / 7))
  outputLinesCount=$((linesCount * 4))
  ((CURRENT_OUTPUT_LINES_COUNT+=outputLinesCount))
  for ((index=0;;index++)); do
    if [ $index -eq $((totalDays)) ]; then
      break
    fi
    # 第一行打印日期信息。
    if [ $((thisMonthDayArr[index])) -eq 0 ]; then
      printf "%s""$NORMAL_COLOR";printf "%-10s" "          "
    else
      if [ $((thisMonthDayArr[index])) -eq $((CURRENT_DAY)) ]; then
        printf "%s""$HIGH_LIGHT_COLOR";
      elif [ $((index % 7)) -eq 5 ] || [ $((index % 7)) -eq 6 ]; then
        printf "%s""$YELLOW_COLOR";
      else
        printf "%s""$NORMAL_COLOR";
      fi
      printf "%-10s" " $((thisMonthDayArr[index]))"
    fi
    if [ $((index % 7)) -eq 6 ]; then
      printf "%s""$NORMAL_COLOR";printf "\n"
      # 第二行打印特殊事件图标。
      specialStartIndex=$((index - 6))
      for ((specialCheck=0;specialCheck<7;specialCheck++)); do
        if [ $((thisMonthDayArr[specialStartIndex])) -eq 0 ]; then
          printf "%s""$NORMAL_COLOR";printf "%-10s" "          "
        else
          realTaskIndex=$((specialStartIndex-preEmptyDaysCount))
          tasks="${CURRENT_SPECIAL_TASKS[realTaskIndex]}"
          tasksLength=$((CURRENT_SPECIAL_TASKS_LENGTH[realTaskIndex]))
          if [ $((tasksLength)) -gt 8 ]; then
            if [ $((thisMonthDayArr[specialStartIndex])) -eq $((CURRENT_DAY)) ]; then
              printf "%s""$HIGH_LIGHT_COLOR";
            elif [ $((specialStartIndex % 7)) -eq 5 ] || [ $((specialStartIndex % 7)) -eq 6 ]; then
              printf "%s""$YELLOW_COLOR";
            else
              printf "%s""$NORMAL_COLOR";
            fi
            printf "%-10s" "节日大事多"
          else
            appendBlanksCount=$((8 - tasksLength))
            for ((blankIndex=0;blankIndex<appendBlanksCount;blankIndex++)); do
              tasks="${tasks}"" "
            done
            printf "%s""$NORMAL_COLOR";printf "%-10s" " ${tasks} "
          fi
        fi
        if [ $((specialStartIndex % 7)) -eq 6 ]; then
          printf "%s""$NORMAL_COLOR";printf "\n"
          # 第三行打印Todo事件图标。
          taskStartIndex=$((index - 6))
          for ((taskCheck=0;taskCheck<7;taskCheck++)); do
            if [ $((thisMonthDayArr[taskStartIndex])) -eq 0 ]; then
              printf "%s""$NORMAL_COLOR";printf "%-10s" "          "
            else
              realTaskIndex=$((taskStartIndex-preEmptyDaysCount))
              tasks="${CURRENT_MONTH_TASKS[realTaskIndex]}"
              tasksLength=$((CURRENT_MONTH_TASKS_LENGTH[realTaskIndex]))
              if [ $((tasksLength)) -gt 8 ]; then
                if [ $((thisMonthDayArr[taskStartIndex])) -eq $((CURRENT_DAY)) ]; then
                  printf "%s""$HIGH_LIGHT_COLOR";
                elif [ $((taskStartIndex % 7)) -eq 5 ] || [ $((taskStartIndex % 7)) -eq 6 ]; then
                  printf "%s""$YELLOW_COLOR";
                else
                  printf "%s""$NORMAL_COLOR";
                fi
                printf "%-10s" " 任务较多 "
              else
                appendBlanksCount=$((8 - tasksLength))
                for ((blankIndex=0;blankIndex<appendBlanksCount;blankIndex++)); do
                  tasks="${tasks}"" "
                done
                printf "%s""$NORMAL_COLOR";printf "%-10s" " ${tasks} "
              fi
            fi
            if [ $((taskStartIndex % 7)) -eq 6 ]; then
              printf "%s""$NORMAL_COLOR";printf "\n"
            else
              printf "%s""$NORMAL_COLOR";printf "┃"
            fi
            taskStartIndex=$((taskStartIndex + 1))
          done
        else
          printf "%s""$NORMAL_COLOR";printf "┃"
        fi
        specialStartIndex=$((specialStartIndex + 1))
      done
      # 打印行尾制表符。
      if [ $((index / 7 + 1)) -eq $((linesCount)) ]; then
        printf "%s""$NORMAL_COLOR";printf "━━━━━━━━━━┻━━━━━━━━━━┻━━━━━━━━━━┻━━━━━━━━━━┻━━━━━━━━━━┻━━━━━━━━━━┻━━━━━━━━━━\n"
      else
        printf "%s""$NORMAL_COLOR";printf "━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━╋━━━━━━━━━━\n"
      fi
    else
      printf "%s""$NORMAL_COLOR";printf "┃"
    fi
  done

  # 特殊事件介绍。
  specialIntroductionLength=${#SPECIAL_INTRODUCTION}
  if [ $((specialIntroductionLength)) -gt 0 ]; then
    printf "%s""$NORMAL_COLOR";printf "%s""\n 节日&重要事件：\n$SPECIAL_INTRODUCTION"
    extraLinesCount=$((SPECIAL_LINES_COUNT + 2))
    ((CURRENT_OUTPUT_LINES_COUNT+=extraLinesCount))
  fi

  # Todo任务介绍。
  tasksIntroductionLength=${#TASKS_INTRODUCTION}
  if [ $((tasksIntroductionLength)) -gt 0 ]; then
    printf "%s""$NORMAL_COLOR";printf "%s""\n 图例：\n$TASKS_INTRODUCTION"
    extraLinesCount=$((TASKS_LINES_COUNT + 2))
    ((CURRENT_OUTPUT_LINES_COUNT+=extraLinesCount))
  fi

  # 特殊事件较多日期提醒。
  buzySpecialDays=""
  buzySpecialLinesCount=0
  for ((index=0;index<thisMonthDays;index++)); do
    tasksLength=$((CURRENT_SPECIAL_TASKS_LENGTH[index]))
    if [ $((tasksLength)) -gt 8 ]; then
      buzySpecialDays="$buzySpecialDays"" $((index + 1))号特殊事件较多：${CURRENT_SPECIAL_TASKS[index]}\n"
      ((buzySpecialLinesCount+=1))
    fi
  done
  buzySpecialDaysLength=${#buzySpecialDays}
  if [ $((buzySpecialDaysLength)) -gt 0 ]; then
    printf "%s""$YELLOW_COLOR";printf "%s""\n 特殊事件较多日提醒：\n$buzySpecialDays"
    extraLinesCount=$((buzySpecialLinesCount + 2))
    ((CURRENT_OUTPUT_LINES_COUNT+=extraLinesCount))
  fi

  # 任务较多日期提醒。
  buzyTasksDays=""
  buzyTasksLinesCount=0
  for ((index=0;index<thisMonthDays;index++)); do
    tasksLength=$((CURRENT_MONTH_TASKS_LENGTH[index]))
    if [ $((tasksLength)) -gt 8 ]; then
      buzyTasksDays="$buzyTasksDays"" $((index + 1))号任务较多：${CURRENT_MONTH_TASKS[index]}\n"
      ((buzyTasksLinesCount+=1))
    fi
  done
  buzyTasksDaysLength=${#buzyTasksDays}
  if [ $((buzyTasksDaysLength)) -gt 0 ]; then
    printf "%s""$HIGH_LIGHT_COLOR";printf "%s""\n 任务繁忙日提醒：\n$buzyTasksDays"
    extraLinesCount=$((buzyTasksLinesCount + 2))
    ((CURRENT_OUTPUT_LINES_COUNT+=extraLinesCount))
  fi

  printf "%s""$NORMAL_COLOR";printf "\n"
  ((CURRENT_OUTPUT_LINES_COUNT+=1))
}

# 指令菜单。
function menuController() {
  ((CURRENT_OUTPUT_LINES_COUNT+=1))
  read -r -sn1 -p " 【←或→切换月份；↑或↓切换年份；其他键退出】请输入：" key
  if [[ $key == $'\e' ]] ; then
    # 方向键由3个字符组成，再读两次。
    read -r -sn1 key
    if [[ "$key" == "[" ]] ; then
      read -r -sn1 key
      case $key in
      A)
        if [ $((CURRENT_YEAR)) -gt $((MIN_YEAR)) ]; then
          CURRENT_YEAR=$((CURRENT_YEAR - 1))
          CURRENT_WEEK_DAY_INDEX=$(date -j -f "%Y-%m-%d" "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}" "+%u")
          if [ "${CURRENT_WEEK_DAY_INDEX}" -eq "7" ]; then
            CURRENT_WEEK_DAY_INDEX=0
          fi
          printf "\e[";printf "%s""${CURRENT_OUTPUT_LINES_COUNT}";printf "A\e[J\n"
          resetResults
          run
          menuController
        else
          printf "\e[1A\e[J\n"
          ((CURRENT_OUTPUT_LINES_COUNT-=1))
          menuController
        fi
        ;;
      B)
        if [ $((CURRENT_YEAR)) -lt $((MAX_YEAR)) ]; then
          CURRENT_YEAR=$((CURRENT_YEAR + 1))
          CURRENT_WEEK_DAY_INDEX=$(date -j -f "%Y-%m-%d" "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}" "+%u")
          if [ "${CURRENT_WEEK_DAY_INDEX}" -eq "7" ]; then
            CURRENT_WEEK_DAY_INDEX=0
          fi
          printf "\e[";printf "%s""${CURRENT_OUTPUT_LINES_COUNT}";printf "A\e[J\n"
          resetResults
          run
          menuController
        else
          printf "\e[1A\e[J\n"
          ((CURRENT_OUTPUT_LINES_COUNT-=1))
          menuController
        fi
        ;;
      C)
        if [ $((CURRENT_YEAR)) -ge $((MAX_YEAR)) ] && [ $((CURRENT_MONTH)) -ge 12 ]; then
          printf "\e[1A\e[J\n"
          ((CURRENT_OUTPUT_LINES_COUNT-=1))
          menuController
        elif [ $((CURRENT_MONTH)) -lt 12 ]; then
          printf "\e[";printf "%s""${CURRENT_OUTPUT_LINES_COUNT}";printf "A\e[J\n"
          CURRENT_MONTH=$((CURRENT_MONTH + 1))
          CURRENT_WEEK_DAY_INDEX=$(date -j -f "%Y-%m-%d" "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}" "+%u")
          if [ "${CURRENT_WEEK_DAY_INDEX}" -eq "7" ]; then
            CURRENT_WEEK_DAY_INDEX=0
          fi
          resetResults
          run
          menuController
        elif [ $((CURRENT_MONTH)) -ge 12 ]; then
          printf "\e[";printf "%s""${CURRENT_OUTPUT_LINES_COUNT}";printf "A\e[J\n"
          CURRENT_MONTH=1
          CURRENT_YEAR=$((CURRENT_YEAR + 1))
          CURRENT_WEEK_DAY_INDEX=$(date -j -f "%Y-%m-%d" "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}" "+%u")
          if [ "${CURRENT_WEEK_DAY_INDEX}" -eq "7" ]; then
            CURRENT_WEEK_DAY_INDEX=0
          fi
          resetResults
          run
          menuController
        fi
        ;;
      D)
        if [ $((CURRENT_YEAR)) -le $((MIN_YEAR)) ] && [ $((CURRENT_MONTH)) -le 1 ]; then
          printf "\e[1A\e[J\n"
          ((CURRENT_OUTPUT_LINES_COUNT-=1))
          menuController
        elif [ $((CURRENT_MONTH)) -gt 1 ]; then
          printf "\e[";printf "%s""${CURRENT_OUTPUT_LINES_COUNT}";printf "A\e[J\n"
          CURRENT_MONTH=$((CURRENT_MONTH - 1))
          CURRENT_WEEK_DAY_INDEX=$(date -j -f "%Y-%m-%d" "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}" "+%u")
          if [ "${CURRENT_WEEK_DAY_INDEX}" -eq "7" ]; then
            CURRENT_WEEK_DAY_INDEX=0
          fi
          resetResults
          run
          menuController
        elif [ $((CURRENT_MONTH)) -le 1 ]; then
          printf "\e[";printf "%s""${CURRENT_OUTPUT_LINES_COUNT}";printf "A\e[J\n"
          CURRENT_MONTH=12
          CURRENT_YEAR=$((CURRENT_YEAR - 1))
          CURRENT_WEEK_DAY_INDEX=$(date -j -f "%Y-%m-%d" "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}" "+%u")
          if [ "${CURRENT_WEEK_DAY_INDEX}" -eq "7" ]; then
            CURRENT_WEEK_DAY_INDEX=0
          fi
          resetResults
          run
          menuController
        fi
        ;;
      esac
      else
        printf "\e[1A\e[J\n"
    fi
  else
    printf "\e[1A\e[J\n"
  fi
}

tasksPathLength=${#TASKS_PATH}
if [ $((tasksPathLength)) -eq 0 ]; then
  printf "%s""$NORMAL_COLOR";printf "\n 请先填写任务单所在目录路径。\n\n"
else
  printf "\n"
  run
  menuController
fi
