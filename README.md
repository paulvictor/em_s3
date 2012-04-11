# S3Interface
  This is a general purpose S3 upload/download library using EM::Deferrables which can retry while accessing from S3. Who doesn't want to retry when they get a 5xx from S3?

# S3Agent
  A serialization framework on top of S3Interface which could possibly occur when you are `put`ting objects in S3 in a reactor loop. Crude but works.

# Caveats
  * Doesn't (yet) run the event loop. I developed this when I was working on a Thin based app server. Future versions may have support for running an event loop.
  * Works only for get_object and put_object. More methods coming soon.
  * Do not define errbacks on instances of S3Interface. It uses errbacks to retry and __always__ succeeds and responds with an error code in case of an error.
  * Feel free to fork and modify.
