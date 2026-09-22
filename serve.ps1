param([int]$Port = 8000)

$ip = [System.Net.IPAddress]::Loopback
$listener = [System.Net.Sockets.TcpListener]::new($ip, $Port)
try {
    $listener.Start()
    Write-Host "Portfolio static server running at http://localhost:$Port/"

    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream)
            $writer = [System.IO.StreamWriter]::new($stream, [System.Text.Encoding]::ASCII)

            $requestLine = $reader.ReadLine()
            if ($requestLine) {
                $parts = $requestLine.Split(' ')
                $url = if ($parts.Length -gt 1) { $parts[1] } else { "/" }
                $path = $url.Split('?')[0].TrimStart('/')
                if ([string]::IsNullOrWhiteSpace($path)) {
                    $path = "index.html"
                }

                while ($line = $reader.ReadLine()) {
                    if ([string]::IsNullOrWhiteSpace($line)) { break }
                }

                $filePath = Join-Path $PSScriptRoot $path
                if (Test-Path $filePath -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                    $contentType = switch ($ext) {
                        ".html" { "text/html; charset=utf-8" }
                        ".css"  { "text/css; charset=utf-8" }
                        ".js"   { "application/javascript; charset=utf-8" }
                        ".json" { "application/json; charset=utf-8" }
                        ".png"  { "image/png" }
                        ".jpg"  { "image/jpeg" }
                        ".jpeg" { "image/jpeg" }
                        ".svg"  { "image/svg+xml" }
                        ".ico"  { "image/x-icon" }
                        ".pdf"  { "application/pdf" }
                        default { "application/octet-stream" }
                    }

                    $writer.WriteLine("HTTP/1.1 200 OK")
                    $writer.WriteLine("Content-Type: $contentType")
                    $writer.WriteLine("Content-Length: " + $bytes.Length)
                    $writer.WriteLine("Connection: close")
                    $writer.WriteLine()
                    $writer.Flush()
                    $stream.Write($bytes, 0, $bytes.Length)
                } else {
                    $notFound = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
                    $writer.WriteLine("HTTP/1.1 404 Not Found")
                    $writer.WriteLine("Content-Type: text/plain; charset=utf-8")
                    $writer.WriteLine("Content-Length: " + $notFound.Length)
                    $writer.WriteLine("Connection: close")
                    $writer.WriteLine()
                    $writer.Flush()
                    $stream.Write($notFound, 0, $notFound.Length)
                }
            }
        } catch {
            # Ignore transient connection errors
        } finally {
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
}
