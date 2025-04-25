determine_policy_key() {
    local usage avg key

    usage=$(get_cpu_usage)
    avg=$(faz_o_urro "$usage")

    key=$(printf "%03d" $((avg / 10 * 10)))

    echo "$key|$avg"
}