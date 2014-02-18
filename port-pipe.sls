#!r6rs
(library (port-pipe)
  (export call-with-port-pipe)
  (import (rnrs) (rnrs mutable-pairs))

(define (make-queue)
  (cons '() '()))

(define (queue-empty? queue)
  (null? (car queue)))

(define (queue-front queue)
  (if (queue-empty? queue) (eof-object) (caar queue)))

(define (enqueue! queue item)
  (let ((n (cons item '())))
    (if (queue-empty? queue)
        (begin (set-car! queue n) (set-cdr! queue n))
        (let ((rear-pair (cdr queue)))
          (set-cdr! rear-pair n)
          (set-cdr! queue n)))
    queue))

(define (dequeue! queue)
  (if (queue-empty? queue)
      (eof-object)
      (let* ((top (car queue))
             (item (car top)))
        (if (null? (cdr top))
            (begin (set-car! queue '())
                   (set-cdr! queue '()))
            (set-car! queue (cdr top)))
        item)))

(define-syntax inc!
  (syntax-rules ()
    ((_ var) (inc! var 1))
    ((_ var p) (set! var (+ var p)))))

(define-syntax dec!
  (syntax-rules ()
    ((_ var) (dec! var 1))
    ((_ var p) (set! var (- var p)))))

(define-syntax let/cc
  (syntax-rules ()
    ((_ var b0 b1 ...)
     (call/cc (lambda(var) b0 b1 ...)))))

(define (call-with-port-pipe productor consumer)
  (let* ((chunks (make-queue))
         (pipe-write-port-closed? #f)
         (position 0)
         (buffer-rest 0)
         (next-p #f)
         (next-c #f))

    (define (pipe-read! bv start count)
      (cond ((zero? count) 0)
            ((< buffer-rest count)
             (if pipe-write-port-closed?
                 (pipe-read! bv start buffer-rest)
                 (begin (let/cc cc
                          (set! next-c cc)
                          (next-p))
                        (pipe-read! bv start count))))
            (else
             (let* ((chunk (queue-front chunks))
                    (chunk-rest (- (bytevector-length chunk) position)))
               (cond ((< count chunk-rest)
                      (bytevector-copy! chunk position bv start count)
                      (dec! buffer-rest count)
                      (inc! position count)
                      count)
                     ((= count chunk-rest)
                      (bytevector-copy! chunk position bv start chunk-rest)
                      (dec! buffer-rest chunk-rest)
                      (set! position 0)
                      (dequeue! chunks)
                      chunk-rest)
                     ((> count chunk-rest)
                      (bytevector-copy! chunk position bv start chunk-rest)
                      (dec! buffer-rest chunk-rest)
                      (set! position 0)
                      (dequeue! chunks)
                      (+ chunk-rest
                         (pipe-read! bv
                                     (+ start chunk-rest)
                                     (- count chunk-rest)))))))))

    (define (pipe-write! bv start count)
      (let ((nbv (make-bytevector count)))
        (bytevector-copy! bv start nbv 0 count)
        (enqueue! chunks nbv)
        (inc! buffer-rest count)
        (let/cc cc
          (set! next-p cc)
          (next-c))
        count))

    (define (pipe-close)
      (set! pipe-write-port-closed? #t))

    (let ((out (make-custom-binary-output-port "productor" pipe-write! #f #f pipe-close))
          (in (make-custom-binary-input-port "consumer" pipe-read! #f #f #f)))
      (set! next-p (lambda()(productor out) (close-port out)))
      (consumer in))))

)
