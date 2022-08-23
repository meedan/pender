module Instagram
    class ApiError < StandardError; end
    class ApiResponseCodeError < StandardError; end
    class ApiAuthenticationError < StandardError; end
end
