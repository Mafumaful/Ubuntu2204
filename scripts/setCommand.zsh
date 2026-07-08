# Proxy 开关
proxyon() {
  export http_proxy="http://127.0.0.1:17891"
  export https_proxy="http://127.0.0.1:17891"
  export all_proxy="socks5://127.0.0.1:17891"
  export HTTP_PROXY="http://127.0.0.1:17891"
  export HTTPS_PROXY="http://127.0.0.1:17891"
  export ALL_PROXY="socks5://127.0.0.1:17891"
  echo "✅ Proxy ON: 127.0.0.1:17891"
}

proxyoff() {
  unset http_proxy https_proxy all_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
  echo "❌ Proxy OFF"
}
