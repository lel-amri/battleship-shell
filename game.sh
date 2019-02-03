#!/bin/sh

##################
# UTIL FUNCTIONS #
##################

prompt_player_name() {
    # args:
    # $1 = variable
    # $2 = player number
    while [ -z "$(eval echo '$'"$1")" ] ; do
        printf "Player $2 name: "
        read -r $1
        if [ -z "$(eval echo '$'"$1")" ] ; then
            echo "Error: Name is empty !"
        fi
    done
    return 0
}

generate_empty_board() {
    i=10
    while [ $i -gt 0 ] ; do
        printf '++++++++++'
        i=$(($i - 1))
    done
    return 0
}

print_board() (
    # args:
    # $1 = board to print
    echo '  ABCDEFGHIJ'
    i=1
    IFS=' '
    echo $1 | fold -w 10 | while read -r line ; do
        printf '%2d%s\n' "$i" "$line"
        i=$(($i + 1))
    done
    return 0
)

coordinates_are_valid() {
    # args:
    # $1 = coordinates
    echo "$1" | grep -E "^[A-J]([1-9]|10)$" >/dev/null
    return $?
}

prompt_board_coords() {
    # args:
    # $1 = variable
    while [ -z "$(eval echo '$'"$1")" ] ; do
        printf 'Enter coordinates: '
        eval "$1"=$(
            read -r coords
            coords=$(echo "$coords" | tr '[a-z]' '[A-Z]')
            echo "$coords" | grep -E "^[A-J]([1-9]|10)$"
        )
        if [ -z "$(eval echo '$'"$1")" ] ; then
            echo "Error: Wrong coordinates ! (Expected example: A4)"
        fi
    done
    return 0
}

prompt_ship_length() {
    # args:
    # $1 = variable
    while [ -z "$(eval echo '$'"$1")" ] ; do
        printf 'Choose ship length: '
        eval "$1"=$(
            read -r length
            echo "$length" | grep "^[0-9]\{1,\}$" >/dev/null
            if [ $? = 0 ] ; then
                length=$(echo "$length" | sed 's/^0\{1,\}//')
                if [ -z "$length" ] ; then
                    echo 0
                else
                    echo "$length"
                fi
            fi
        )
        if [ -z "$(eval echo '$'"$1")" ] ; then
            echo "Error: Wrong ship length ! (Must be a decimal number)"
        fi
    done
    return 0
}

print_ships_to_place() (
    # args:
    # $1 = ships
    for ship in $(echo "$1" | tr ';' ' ') ; do
        len=$(echo "$ship" | cut -f 1 -d '=')
        count=$(echo "$ship" | cut -f 2 -d '=')
        if [ "$count" -gt 0 ] ; then
            echo "There is $count ships of length $len to place"
        fi
    done
    return 0
)

ship_in_pool() (
    # args:
    # $1 = ships
    # $2 = ship length
    for ship in $(echo "$1" | tr ';' ' ') ; do
        len=$(echo "$ship" | cut -f 1 -d '=')
        count=$(echo "$ship" | cut -f 2 -d '=')
        if [ "$2" -eq "$len" ] ; then
            if [ "$count" -gt 0 ] ; then
                return 0
            fi
            break
        fi
    done
    return 1
)

ships_remaining() (
    # args:
    # $1 = ships
    for ship in $(echo "$1" | tr ';' ' ') ; do
        count=$(echo "$ship" | cut -f 2 -d '=')
        if [ "$count" -gt 0 ] ; then
            return 0
        fi
    done
    return 1
)

prompt_direction() {
    # args:
    # $1 = variable
    while [ -z "$(eval echo '$'"$1")" ] ; do
        printf 'Choose direction: '
        eval "$1"=$(
            read -r direction
            direction=$(echo "$direction" | tr '[a-z]' '[A-Z]')
            echo "$direction" | grep -E "^([NEWS]|(NORTH|EAST|SOUTH|WEST))$" | cut -c 1
        )
        if [ -z "$(eval echo '$'"$1")" ] ; then
            echo "Error: Wrong direction ! (Must be North, East, South or West)"
        fi
    done
    return 0
}

coordinates_to_line() {
    # args:
    # $1 = coords
    echo "$1" | cut -c 2-
    return 0
}

coordinates_to_column() (
    # args:
    # $1 = coords
    column=$(echo "$1" | cut -c 1)
    i=1
    for c in A B C D E F G H I J ; do
        if [ "$column" = $c ] ; then
            echo $i
            return 1
        fi
        i=$((i + 1))
    done
    return 0
)

get_column_from_board() (
    # args:
    # $1 = board
    # $2 = column
    echo "$1" | cut -c $2,$((10 + $2)),$((20 + $2)),$((30 + $2)),$((40 + $2)),\
$((50 + $2)),$((60 + $2)),$((70 + $2)),$((80 + $2)),$((90 + $2))
)

get_line_from_board() {
    # args:
    # $1 = board
    # $2 = line
    echo "$1" | cut -c $((($2 - 1) * 10 + 1))-$((($2 - 1) * 10 + 10))
}

column_line_to_coordinates() {
    # args:
    # $1 = column
    # $2 = line
    echo $(
        i=1
        for c in A B C D E F G H I J ; do
            if [ "$1" = $i ] ; then
                echo $c
            fi
            i=$((i + 1))
        done
    )$2
    return 0
}

simplify_place() {
    # args:
    # $1 = variable coordinates
    # $2 = variable direction
    # $3 = ship length
    case $(eval echo '$'"$2") in
        N )
            (
                coords=$(eval echo '$'"$1")
                column=$(coordinates_to_column "$coords")
                line=$(($(coordinates_to_line "$coords") - "$3" + 1))
                if [ "$line" -ge 1 ] ; then
                    return 0
                fi
                return 1
            )
            if [ $? != 0 ] ; then
                return 1
            fi
            eval "$1"=$(
                coords=$(eval echo '$'"$1")
                column_line_to_coordinates $(coordinates_to_column "$coords") $(($(coordinates_to_line "$coords") - "$3" + 1))
            )
            eval "$2"=S
            ;;
        W )
            (
                coords=$(eval echo '$'"$1")
                column=$(($(coordinates_to_column "$coords") - "$3" + 1))
                line=$(coordinates_to_line "$coords")
                if [ "$column" -ge 1 ] ; then
                    return 0
                fi
                return 1
            )
            if [ $? != 0 ] ; then
                return 1
            fi
            eval "$1"=$(
                coords=$(eval echo '$'"$1")
                column_line_to_coordinates $(($(coordinates_to_column "$coords") - "$3" + 1)) $(coordinates_to_line "$coords")
            )
            eval "$2"=E
            ;;
    esac
    return 0
}

focus_place() (
    # args:
    # $1 = board
    # $2 = coodinates
    # $3 = direction (Can only be S or E)
    # $4 = length
    case "$3" in
        S )
            line=$(coordinates_to_line "$2")
            column=$(coordinates_to_column "$2")
            board_column=$(get_column_from_board "$1" "$column")
            echo $board_column | cut -c "$line-$(($line + "$4" - 1))"
            ;;
        E )
            line=$(coordinates_to_line "$2")
            column=$(coordinates_to_column "$2")
            board_line=$(get_line_from_board "$1" "$line")
            echo $board_line | cut -c "$column-$(($column + "$4" - 1))"
            ;;
        * )
            return 1
            ;;
    esac
    return 0
)

place_is_valid() (
    # args:
    # $1 = coordinates
    # $2 = direction (Can only be S or E)
    # $3 = length
    line=$(coordinates_to_line "$1")
    column=$(coordinates_to_column "$1")
    line_max="$line"
    column_max="$column"
    case "$2" in
        S )
            line_max=$(($line + "$3" - 1))
            ;;
        E )
            column_max=$(($column + "$3" - 1))
            ;;
        * )
            return 1
            ;;
    esac
    if [ "$line" -lt 1 -o "$line" -gt 10 ] || [ "$line_max" -lt 1 -o "$line_max" -gt 10 ]\
|| [ "$column" -lt 1 -o "$column" -gt 10 ] || [ "$column_max" -lt 1 -o "$column_max" -gt 10 ] ; then
        return 1
    fi
    return 0
)

place_ship() (
    # args:
    # $1 = board
    # $2 = ship no
    # $3 = ship length
    # $4 = ship root coordinates
    # $5 = ship direction (Can only be S or E)
    if ! place_is_valid "$4" "$5" "$3" ; then
        return 1
    fi
    focus=$(focus_place "$1" "$4" "$5" "$3")
    if ! echo "$focus" | grep ^+ >/dev/null ; then
        return 1
    fi
    line=$(coordinates_to_line "$4")
    column=$(coordinates_to_column "$4")
    case "$5" in
        S )
            lin_max=$((line + "$3" - 1))
            echo "$1" | fold -w 10 | awk "BEGIN { OFS=\"\" ; ORS=\"\" ; i=1 }
{
  if (i >= $line && i <= $lin_max) {
    s1=substr(\$1, 1, $column - 1)
    s2=substr(\$1, $column + 1)
    print s1 $2 s2
  } else {
    print \$1
  }
  i++
}"
            ;;
        E )
            col_max=$(($column + "$3" - 1))
            echo "$1" | fold -w 10 | awk "BEGIN { OFS=\"\" ; ORS=\"\" ; i=1 }
{
  if (i == $line) {
    s1=substr(\$1, 1, $column - 1)
    s2=substr(\$1, $col_max + 1)
    ship=\"\"
    for (j=0 ; j<$3 ; j++)
        ship=ship \"$2\"
    print s1 ship s2
  } else {
    print \$1
  }
  i++
}"
            ;;
    esac
    return 0
)

remove_ship_from_set() {
    # args:
    # $1 = variable ships set
    # $2 = ship length
    eval $1=\"$( (
        ships=$(eval echo '$'"$1")
        IFS=';'
        for ship in $ships ; do
            len=$(echo $ship | cut -d = -f 1)
            count=$(echo $ship | cut -d = -f 2)
            if [ "$len" -eq $2 ] ; then
                if [ "$count" -gt 0 ] ; then
                    count=$(($count - 1))
                fi
            fi
            echo "$len=$count"
        done
    ) | tr '\n' ';' | sed 's/;\{1,\}$//')\"
    return 0
}

get_whats_on_coordinates() (
    # args:
    # $1 = board (hitsboard or shipsboard)
    # $2 = coordinates
    line=$(coordinates_to_line "$2")
    column=$(coordinates_to_column "$2")
    echo "$1" | fold -w 10 | awk -v line=$line -v column=$column "BEGIN { OFS=\"\" ; ORS=\"\" ; i=1 }
{
  if (i == $line) {
    print substr(\$1, $column, 1)
    exit
  }
  i++
}"
    return 0
)

place_hit() {
    # args:
    # $1 = variable containing hitsboard
    # $2 = hit coordinates
    # $3 = hit type
    eval $1=$(
        case "$3" in
            hit )
                hit=X
                ;;
            miss )
                hit=O
                ;;
        esac
        line=$(coordinates_to_line "$2")
        column=$(coordinates_to_column "$2")
        echo "$(eval echo '$'"$1")" | fold -w 10 | awk "BEGIN { OFS=\"\" ; ORS=\"\" ; i=1 }
{
  if (i == $line) {
    s1=substr(\$1, 1, $column - 1)
    s2=substr(\$1, $column + 1)
    print s1 \"$hit\" s2
  } else {
    print \$1
  }
  i++
}"
    )
    return 0
}

mask_board_with_hitsboard() (
    # args:
    # $1 = board
    # $2 = hitsboard
    # Okay, I admit, here I'm cheating !
    awk -v "board=$1" -v "hitsboard=$2" "BEGIN { FS=\"\" ; OFS=\"\" ; ORS=\"\" ; split(board, b) ; split(hitsboard, h) }
END {
  for (i=1 ; i<=100 ; i++) {
    if (b[i] != \"+\" ) {
      if (h[i] != \"+\") {
        print \"+\"
      } else {
        print \"-\"
      }
    } else {
      print \"+\"
    }
  }
}" </dev/null
    return 0
)

no_ships_left_on_board() (
    # args:
    # $1 = board
    # $2 = hitsboard
    mask_board_with_hitsboard $1 $2 | grep '^+\{100\}$' >/dev/null
    if [ "$?" == "0" ] ; then
        return 0
    fi
    return 1
)

#############
# GAME MAIN #
#############

acquire_ships() {
    # args:
    # $1 = player name
    # $2 = ships to place
    # $3 = variable where to store board
    board=$(generate_empty_board)
    shipno=0
    _ships="$2"
    while ships_remaining "$_ships" ; do
        clear
        echo "$1, place your ships"
        print_board "$board"
        print_ships_to_place "$_ships"
        while true ; do
            while true ; do
                while true ; do
                    len=
                    prompt_ship_length len
                    if ship_in_pool "$_ships" $len ; then
                        break
                    fi
                    echo "Error: There is no ship of length $len to place !"
                done
                coords=
                prompt_board_coords coords
                dir=
                prompt_direction dir
                simplify_place coords dir $len
                if [ $? = 0 ] ; then
                    break
                fi
                echo "Error: Can't place ship here !"
            done
            _board=$(place_ship $board $shipno $len $coords $dir)
            if [ $? != 0 ] ; then
                echo "Error: Can't place ship here !"
                continue
            fi
            board="$_board"
            remove_ship_from_set _ships $len
            shipno=$(($shipno + 1))
            break
        done
    done
    eval $3=\"\$board\"
}

ships="2=4;3=3;4=2;6=1"
clear
prompt_player_name player1_name 1
acquire_ships $player1_name $ships player1_board
player1_hitboard=$(generate_empty_board)
clear
prompt_player_name player2_name 2
acquire_ships $player2_name $ships player2_board
player2_hitboard=$(generate_empty_board)
clear
run=1
while [ "$run" != "0" ] ; do
    echo "$player1_name, your turn to fire !"
    print_board $player1_hitboard
    while [ "$run" != "0" ] ; do
        coords=
        prompt_board_coords coords
        hit=$(get_whats_on_coordinates "$player1_hitboard" "$coords")
        if [ "$hit" != "+" ] ; then
            echo "You already fired here !"
            continue
        fi
        hit=$(get_whats_on_coordinates "$player2_board" "$coords")
        case "$hit" in
            [0-9A-Z] )
                echo "You hit !"
                place_hit player1_hitboard "$coords" hit
                if no_ships_left_on_board "$player2_board" "$player1_hitboard" ; then
                    printf '\n########################################\n'
                    echo "$player1_name, you win !"
                    run=0
                    break
                fi
                ;;
            + )
                echo "You missed !"
                place_hit player1_hitboard "$coords" miss
                ;;
        esac
        break
    done
    if [ "$run" == "0" ] ; then
        break
    fi
    echo "$player2_name, your turn to fire !"
    print_board $player2_hitboard
    while [ "$run" != "0" ] ; do
        coords=
        prompt_board_coords coords
        hit=$(get_whats_on_coordinates "$player2_hitboard" "$coords")
        if [ "$hit" != "+" ] ; then
            echo "You already fired here !"
            continue
        fi
        hit=$(get_whats_on_coordinates "$player1_board" "$coords")
        case "$hit" in
            [0-9A-Z] )
                echo "You hit !"
                place_hit player2_hitboard "$coords" hit
                if no_ships_left_on_board "$player1_board" "$player2_hitboard" ; then
                    printf '\n########################################\n'
                    echo "$player2_name, you win !"
                    run=0
                    break
                fi
                ;;
            + )
                echo "You missed !"
                place_hit player2_hitboard "$coords" miss
                ;;
        esac
        break
    done
done
printf '\n'
echo "$player1_name's board:"
print_board "$player1_board"
printf '\n'
echo "$player2_name's board:"
print_board "$player2_board"
