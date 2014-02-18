(import (rnrs)
        (port-pipe))

(call-with-port-pipe
 (lambda(out)
   (put-u8 out 15)
   (put-u8 out 2)
   (put-u8 out 5))
 (lambda(in)
   (display (get-bytevector-all in))
   (display "end")))
