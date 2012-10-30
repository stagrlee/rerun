#!/usr/bin/env bash
#
# NAME
#
#   add-command
#
# DESCRIPTION
#
#   add command to module
#
#/ usage: stubbs:add-command  --command|-c <> --module|-m <> [-overwrite] [-template <>]

# Source common function library
. $RERUN_MODULE_DIR/lib/functions.sh || { echo >&2 "failed loading function library" ; exit 1 ; }


# Init the handler
rerun_init 


# Get the options
while [ "$#" -gt 0 ]; do
    OPT="$1"
    case "$OPT" in
    # options without arguments
	# options with arguments
	-c|--command)
	    rerun_option_check "$#" "$1"
	    COMMAND="$2"
	    shift
	    ;;
	--description)
	    rerun_option_check "$#" "$1"
	    DESC="$2"
	    shift
	    ;;
	-m|--module)
	    rerun_option_check "$#" "$1"
	    MODULE="$2"
	    shift
	    ;;
	--overwrite)
	    rerun_option_check "$#" "$1"
	    OVERWRITE="$2"
	    shift
	    ;;
	-t|--template)
	    rerun_option_check "$#" "$1"
	    TEMPLATE="$2"
	    shift
	    ;;
        # unknown option
	-?)
	    rerun_option_usage
        exit 2
	    ;;
	  # end of options, just arguments left
	*)
	    break
    esac
    shift
done

# Post processes the options
[ -z "$COMMAND" ] && {
    echo "Command: "
    read COMMAND
}

[ -z "$DESC" ] && {
    echo "Description: "
    read DESC
}

[ -z "$MODULE" ] && {
    echo "Module: "
    select MODULE in $(rerun_modules $RERUN_MODULES);
    do
	echo "You picked module $MODULE ($REPLY)"
	break
    done
}

[ -z "$TEMPLATE" ] && {
    TEMPLATE=$RERUN_MODULE_DIR/lib/bash/templates/default.sh
}

[ ! -r "$TEMPLATE" ] && {
    rerun_option_error "TEMPLATE does not exist: $TEMPLATE"
}

# Create command structure
mkdir -p $RERUN_MODULES/$MODULE/commands/$COMMAND || rerun_die

VARIABLES=$(list_optionVariables $RERUN_MODULES $MODULE $COMMAND)

# Read language setting for module. Set it to 'bash' as a default.
LANGUAGE=$(. $RERUN_MODULES/$MODULE/metadata; echo ${LANGUAGE:-bash});

[ ! -f $RERUN_MODULE_DIR/lib/$LANGUAGE/metadata ] && {
    rerun_die "language unsupported: $LANGUAGE"
}

.  $RERUN_MODULE_DIR/lib/$LANGUAGE/metadata || {
    rerun_die "error reading  $RERUN_MODULE_DIR/lib/$LANGUAGE/metadata"
}

[ -z "$RERUN_COMMAND_SCRIPT" ] && {
    rerun_die "required metadata not found: RERUN_COMMAND_SCRIPT"
}

CMD_SCRIPT=$RERUN_MODULES/$MODULE/commands/$COMMAND/$RERUN_COMMAND_SCRIPT


# Generate a boiler plate implementation
[ ! -f $CMD_SCRIPT -o -n "$OVEWRITE" ] && {
    sed -e "s/@NAME@/$COMMAND/g" \
	-e "s/@MODULE@/$MODULE/g" \
	-e "s/@DESCRIPTION@/$DESC/g" \
    -e "s/@VARIABLES@/$VARIABLES/g" \
	$TEMPLATE > $CMD_SCRIPT || rerun_die
    chmod +x $CMD_SCRIPT || rerun_die
    echo "Wrote command script: $CMD_SCRIPT"
}

# Generate a unit test script
mkdir -p $RERUN_MODULES/$MODULE/tests || rerun_die "failed creating tests directory"
[ ! -f $RERUN_MODULES/$MODULE/tests/$COMMAND-1-test.sh -o -n "$OVEWRITE" ] && {
    sed -e "s/@NAME@/default/g" \
	-e "s/@MODULE@/$MODULE/g" \
	-e "s/@COMMAND@/$COMMAND/g" \
	-e "s;@RERUN@;${RERUN};g" \
	-e "s;@RERUN_MODULES@;${RERUN_MODULES};g" \
	$RERUN_MODULE_DIR/templates/test.roundup > $RERUN_MODULES/$MODULE/tests/$COMMAND-1-test.sh || rerun_die
    echo "Wrote test script: $RERUN_MODULES/$MODULE/tests/$COMMAND-1-test.sh"
}

# Generate command metadata
(
cat <<EOF
# generated by stubbs:add-command
# $(date)
NAME=$COMMAND
DESCRIPTION="$DESC"

EOF
) > $RERUN_MODULES/$MODULE/commands/$COMMAND/metadata || rerun_die

# Done
