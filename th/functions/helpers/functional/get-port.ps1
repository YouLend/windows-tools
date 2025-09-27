function find_available_port {
    for ($i = 1; $i -le 100; $i++) {
        $port = Get-Random -Minimum 40000 -Maximum 60000
        $tcpConnection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if (-not $tcpConnection) {
            return $port
        }
    }
    return 50000
}