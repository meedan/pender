module LapisConstants
  class ErrorCodes
    UNAUTHORIZED = 1
    MISSING_PARAMETERS = 2
    ID_NOT_FOUND = 3
    INVALID_VALUE = 4
    UNKNOWN = 5
    AUTH = 6
    WARNING = 7
    MISSING_OBJECT = 8
    DUPLICATED = 9
    TIMEOUT = 10
    API_LIMIT_REACHED = 11
    UNSAFE = 12
    ARCHIVER_HOST_SKIPPED = 20
    ARCHIVER_NOT_FOUND = 21
    ARCHIVER_DISABLED = 22
    ARCHIVER_NOT_SUPPORTED_MEDIA = 23
    ARCHIVER_FAILURE = 24
    ARCHIVER_ERROR = 25
    ALL = %w(UNAUTHORIZED MISSING_PARAMETERS ID_NOT_FOUND INVALID_VALUE UNKNOWN AUTH WARNING MISSING_OBJECT DUPLICATED TIMEOUT API_LIMIT_REACHED UNSAFE ARCHIVER_HOST_SKIPPED ARCHIVER_NOT_FOUND ARCHIVER_DISABLED ARCHIVER_NOT_SUPPORTED_MEDIA ARCHIVER_FAILURE ARCHIVER_ERROR)
  end
end
