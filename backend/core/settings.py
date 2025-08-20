"""
Django settings for AIoT Smart System.

This module contains the configuration settings for the AIoT Smart System backend.
The system supports IoT device management, real-time telemetry, and MQTT communication.

For more information on this file, see:
https://docs.djangoproject.com/en/4.2/topics/settings/
"""

import os
from datetime import timedelta
from pathlib import Path

import environ

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# Environment configuration with sensible defaults
env = environ.Env(
    # Core Django settings
    DJANGO_DEBUG=(bool, False),
    SECRET_KEY=(str, "changeme-in-production"),
    ALLOWED_HOSTS=(str, "*"),
    
    # Database and Cache
    DATABASE_URL=(str, f"sqlite:///{BASE_DIR / 'db.sqlite3'}"),
    REDIS_URL=(str, "redis://localhost:6379/0"),
    
    # CORS and API settings
    CORS_ALLOWED_ORIGINS=(str, ""),
    
    # IoT specific settings
    ENABLE_MQTT_WORKER=(bool, True),
    
    # Celery settings
    CELERY_BROKER_URL=(str, "redis://localhost:6379/1"),
    CELERY_RESULT_BACKEND=(str, "redis://localhost:6379/1"),
)

# Read environment variables from .env file
environ.Env.read_env(os.path.join(BASE_DIR, "..", ".env"))

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = env("SECRET_KEY")

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = env("DJANGO_DEBUG")

# Hosts/domain names that this Django site can serve
ALLOWED_HOSTS = [h.strip() for h in env("ALLOWED_HOSTS").split(",") if h.strip()] or ["*"]

# Application definition
INSTALLED_APPS = [
    # Django built-in apps
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    
    # Third-party packages
    "rest_framework",
    "rest_framework.authtoken",
    "drf_spectacular",  # API documentation
    "corsheaders",      # CORS handling
    "channels",         # WebSocket support
    
    # Local applications
    "apps.accounts",    # User authentication and management
    "apps.devices",     # IoT device management and telemetry
]

# Middleware configuration
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",      # Security headers
    "whitenoise.middleware.WhiteNoiseMiddleware",         # Static file serving
    "django.contrib.sessions.middleware.SessionMiddleware",
    "corsheaders.middleware.CorsMiddleware",              # CORS handling
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",          # CSRF protection
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",  # Clickjacking protection
]

# URL configuration
ROOT_URLCONF = "core.urls"

# Template configuration
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    }
]

# ASGI application for WebSocket support
ASGI_APPLICATION = "core.asgi:application"

# Database configuration
# https://docs.djangoproject.com/en/4.2/ref/settings/#databases
DATABASES = {
    "default": env.db_url("DATABASE_URL")
}

# Password validation
# https://docs.djangoproject.com/en/4.2/ref/settings/#auth-password-validators
AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {
            "min_length": 8,
        }
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

# Internationalization
# https://docs.djangoproject.com/en/4.2/topics/i18n/
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/4.2/howto/static-files/
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Static files storage configuration
if DEBUG:
    # For development, use simple storage without manifest
    STATICFILES_STORAGE = "whitenoise.storage.CompressedStaticFilesStorage"
else:
    # For production, use manifest storage for cache busting
    STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

# Default primary key field type
# https://docs.djangoproject.com/en/4.2/ref/settings/#default-auto-field
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Django REST Framework configuration
REST_FRAMEWORK = {
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 50,
    "DEFAULT_FILTER_BACKENDS": [
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ],
}

# API Documentation settings
SPECTACULAR_SETTINGS = {
    "TITLE": "AIoT Smart System API",
    "DESCRIPTION": "A comprehensive IoT platform for device management, real-time telemetry, and automation",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "COMPONENT_SPLIT_REQUEST": True,
}

# CORS configuration
CORS_ALLOWED_ORIGINS = [o.strip() for o in env("CORS_ALLOWED_ORIGINS").split(",") if o.strip()]
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_ALL_ORIGINS = DEBUG  # Only allow all origins in development

# WebSocket channel layers configuration
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [env("REDIS_URL")],
        },
    }
}

# MQTT broker configuration for IoT communication
MQTT = {
    "HOST": os.environ.get("MQTT_BROKER_URL", "localhost"),
    "PORT": int(os.environ.get("MQTT_BROKER_PORT", 1883)),
    "ENABLE": env("ENABLE_MQTT_WORKER"),
    "KEEPALIVE": 60,
    "QOS": 1,
}

# JWT Authentication settings
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(hours=12),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "SIGNING_KEY": SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "AUTH_TOKEN_CLASSES": ("rest_framework_simplejwt.tokens.AccessToken",),
}

# Celery configuration for background tasks
CELERY_BROKER_URL = env("CELERY_BROKER_URL")
CELERY_RESULT_BACKEND = env("CELERY_RESULT_BACKEND")
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
CELERY_ENABLE_UTC = True
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 30 * 60  # 30 minutes
CELERY_TASK_SOFT_TIME_LIMIT = 25 * 60  # 25 minutes

# Security settings for production
if not DEBUG:
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_SECONDS = 31536000  # 1 year
    SECURE_REDIRECT_EXEMPT = []
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    X_FRAME_OPTIONS = "DENY"

# Logging configuration
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "{levelname} {asctime} {module} {process:d} {thread:d} {message}",
            "style": "{",
        },
        "simple": {
            "format": "{levelname} {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "simple",
        },
        "file": {
            "class": "logging.FileHandler",
            "filename": "debug.log",
            "formatter": "verbose",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO" if not DEBUG else "DEBUG",
    },
    "loggers": {
        "django": {
            "handlers": ["console", "file"],
            "level": "INFO",
            "propagate": False,
        },
        "apps.devices": {
            "handlers": ["console", "file"],
            "level": "DEBUG" if DEBUG else "INFO",
            "propagate": False,
        },
    },
}


