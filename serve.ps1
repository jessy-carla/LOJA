$prefix = 'http://localhost:8000/'
$root = (Get-Location).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
} catch {
    Write-Error "Falha ao iniciar HttpListener: $_"
    exit 1
}
Write-Host "Servindo $root em http://localhost:8000/ (Ctrl+C para parar)"

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $raw = [System.Uri]::UnescapeDataString($request.Url.AbsolutePath).TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($raw)) { $raw = 'inicio.html' }
    $filePath = Join-Path $root $raw

    if (Test-Path $filePath -PathType Leaf) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime = switch ($ext) {
                '.html' { 'text/html; charset=utf-8' }
                '.htm'  { 'text/html; charset=utf-8' }
                '.css'  { 'text/css' }
                '.js'   { 'application/javascript' }
                '.png'  { 'image/png' }
                '.jpg'  { 'image/jpeg' }
                '.jpeg' { 'image/jpeg' }
                '.gif'  { 'image/gif' }
                default { 'application/octet-stream' }
            }
            $response = $context.Response
            $response.ContentType = $mime
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
            $response.Close()
        } catch {
            Write-Warning ("Erro ao servir {0}: {1}" -f $filePath, $_)
            $context.Response.StatusCode = 500
            $msg = '500 Internal Server Error'
            $buf = [System.Text.Encoding]::UTF8.GetBytes($msg)
            $context.Response.OutputStream.Write($buf,0,$buf.Length)
            $context.Response.Close()
        }
    } else {
        $context.Response.StatusCode = 404
        $msg = '404 Not Found'
        $buf = [System.Text.Encoding]::UTF8.GetBytes($msg)
        $context.Response.ContentLength64 = $buf.Length
        $context.Response.OutputStream.Write($buf,0,$buf.Length)
        $context.Response.Close()
    }
}

$listener.Stop()
$listener.Close()
