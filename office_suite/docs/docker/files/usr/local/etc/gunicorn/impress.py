# Gunicorn-django settings
import os

port = os.environ.get("PORT", "8080")
bind = [f"0.0.0.0:{port}"]
name = "impress"
python_path = "/app"

# Run
graceful_timeout = 90
timeout = 90
workers = 3

# Logging
# Using '-' for the access log file makes gunicorn log accesses to stdout
accesslog = "-"
# Using '-' for the error log file makes gunicorn log errors to stderr
errorlog = "-"
loglevel = "info"
