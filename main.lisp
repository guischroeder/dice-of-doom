; To play against a human:
; (play-vs-human (game-tree (gen-board) 0 0 t))

; To play against the computer:
; (play-vs-computer (game-tree (gen-board) 0 0 t))

(load "lazy")

(defparameter *num-players* 4)
(defparameter *max-dice* 5)
(defparameter *board-size* 5)
(defparameter *board-hexnum* (* *board-size* *board-size*))

(defun board-array (lst)
  (make-array *board-hexnum* :initial-contents lst))

(defun gen-board ()
  (board-array (loop for n below *board-hexnum*
                     collect (list (random *num-players*)
                                   (1+ (random *max-dice*))))))

(defun player-letter (n)
  (code-char (+ 97 n)))

(defun draw-board (board)
  (loop for y below *board-size*
        do (progn (fresh-line)
                  (loop repeat (- *board-size* y)
                        do (princ "  "))
                  (loop for x below *board-size*
                        for hex = (aref board (+ x (* *board-size* y)))
                        do (format t "~a-~a " (player-letter (first hex))
                                              (second hex))))))

(defun game-tree (board player spare-dice first-move)
  (list player
        board
        (add-passing-move board
                          player
                          spare-dice
                          first-move
                          (attacking-moves board player spare-dice))))

(defun add-passing-move (board player spare-dice first-move moves)
  (if first-move
      moves
      (lazy-cons (list nil
                  (game-tree (add-new-dice board player (1- spare-dice))
                             (mod (1+ player) *num-players*)
                             0
                             t))
            moves)))

(defun attacking-moves (board cur-player spare-dice)
  (labels ((player (pos)
             (car (aref board pos)))
           (dice (pos)
             (cadr (aref board pos))))
    (lazy-mapcan (lambda (src)
                   (if (eq (player src) cur-player)
                       (lazy-mapcan (lambda (dst)
                                      (if (and (not (eq (player dst) cur-player))
                                               (> (dice src) (dice dst)))
                                          (make-lazy (list (list (list src dst)
                                                                 (game-tree (board-attack board cur-player src dst (dice src))
                                                                            cur-player
                                                                            (+ spare-dice (dice dst))
                                                                            nil)
                                                                 (game-tree (board-attack-fail board cur-player src dst (dice src))
                                                                            cur-player
                                                                            (+ spare-dice (dice dst))
                                                                            nil))))
                                          (lazy-nil)))
                                    (make-lazy (neighbors src)))
                       (lazy-nil)))
                 (make-lazy (loop for n below *board-hexnum*
                                  collect n)))))

(defun neighbors (pos)
  (let ((up (- pos *board-size*))
        (down (+ pos *board-size*)))
    (loop for p in (append (list up down)
                           (unless (zerop (mod pos *board-size*))
                             (list (1- up) (1- pos)))
                           (unless (zerop (mod (1+ pos) *board-size*))
                             (list (1+ pos) (1+ down))))
          when (and (>= p 0) (< p *board-hexnum*))
          collect p)))

(defun board-attack (board player src dst dice)
  (board-array (loop for pos from 0
                     for hex across board
                     collect (cond ((eq pos src) (list player 1))
                                   ((eq pos dst) (list player (1- dice)))
                                   (t hex)))))

(defun board-attack-fail (board player src dst dice)
  (board-array (loop for pos from 0
                     for hex across board
                     collect (if (eq pos src)
                                 (list player 1)
                                 hex))))

(defun roll-dice (dice-num)
  (let ((total (loop repeat dice-num
                     sum (1+ (random 6)))))
    (fresh-line)
    (format t "On ~a dice rolled ~a. " dice-num total)
    total))

(defun roll-against (src-dice dst-dice)
  (> (roll-dice src-dice) (roll-dice dst-dice)))

(defun pick-chance-branch (board move)
  (labels ((dice (pos)
             (cadr (aref board pos))))
    (let ((path (car move)))
      (if (or (null path) (roll-against (dice (car path))
                                        (dice (cadr path))))
          (cadr move)
          (caddr move)))))

(defun get-connected (board player pos)
  (labels ((check-pos (pos visited)
             (if (and (eq (car (aref board pos)) player)
                      (not (member pos visited)))
                 (check-neighbors (neighbors pos) (cons pos visited))
                 visited))
           (check-neighbors (lst visited)
             (if lst
                 (check-neighbors (cdr lst) (check-pos (car lst) visited))
                 visited)))
    (check-pos pos '())))

(defun largest-cluster-size (board player)
  (labels ((f (pos visited best)
              (if (< pos *board-hexnum*)
                  (if (and (eq (car (aref board pos)) player)
                           (not (member pos visited)))
                      (let* ((cluster (get-connected board player pos))
                             (size (length cluster)))
                        (if (> size best)
                            (f (1+ pos) (append cluster visited) size)
                            (f (1+ pos) (append cluster visited) best)))
                      (f (1+ pos) visited best))
                  best)))
    (f 0 '() 0)))

(defun add-new-dice (board player spare-dice)
  (labels ((f (lst n)
              (cond ((zerop n) lst)
                    ((null lst) nil)
                    (t (let ((cur-player (caar lst))
                             (cur-dice (cadar lst)))
                         (if (and (eq cur-player player) (< cur-dice *max-dice*))
                             (cons (list cur-player (1+ cur-dice))
                                   (f (cdr lst) (1- n)))
                             (cons (car lst) (f (cdr lst) n))))))))
    (board-array (f (coerce board 'list)
                        (largest-cluster-size board player)))))

(defun play-vs-human (tree)
  (print-info tree)
  (if (not (lazy-null (caddr tree)))
      (play-vs-human (handle-human tree))
      (announce-winner (cadr tree))))

(defun print-info (tree)
  (fresh-line)
  (format t "current player = ~a" (player-letter (car tree)))
  (draw-board (cadr tree)))

(defun handle-human (tree)
  (fresh-line)
  (princ "choose your move:")
  (let ((moves (caddr tree)))
    (labels ((print-moves (moves n)
               (unless (lazy-null moves)
                 (let* ((move (lazy-car moves))
                        (action (car move)))
                   (fresh-line)
                   (format t "~a. " n)
                   (if action
                       (format t "~a -> ~a" (car action) (cadr action))
                       (princ "end turn")))
                 (print-moves (lazy-cdr moves) (1+ n)))))
      (print-moves moves 1))
      (fresh-line)
      (pick-chance-branch (cadr (lazy-nth (1- (read)) moves)))))

(defun winners (board)
  (let* ((tally (loop for hex across board
                      collect (car hex)))
         (totals (mapcar (lambda (player)
                           (cons player (count player tally)))
                         (remove-duplicates tally)))
         (best (apply #'max (mapcar #'cdr totals))))
    (mapcar #'car
            (remove-if (lambda (x)
                         (not (eq (cdr x) best)))
                       totals))))

(defun announce-winner (board)
  (fresh-line)
  (let ((w (winners board)))
    (if (> (length w) 1)
        (format t "The game is a tie between ~a" (mapcar #'player-letter w))
        (format t "The winner is ~a" (player-letter (car w))))))

(defun score-board (board player)
  (loop for hex across board
        for pos from 0
        sum (if (eq (car hex) player)
                (if (threatened pos board)
                    1
                    2)
                -1)))

(defun threatened (pos board)
  (let* ((hex (aref board pos))
         (player (car hex))
         (dice (cadr hex)))
    (loop for n in (neighbors pos)
          do (let* ((nhex (aref board n))
                    (nplayer (car nhex))
                    (ndice (cadr nhex)))
               (when (and (not (eq player nplayer)) (> ndice dice))
                 (return t))))))

(defun rate-position (tree player)
   (let ((moves (caddr tree)))
     (if (not (lazy-null moves))
         (apply (if (eq (car tree) player)
                    #'max
                    #'min)
                (get-ratings tree player))
         (score-board (cadr tree) player))))

(defun get-ratings (tree player)
  (let ((board (cadr tree)))
    (labels ((dice (pos)
               (cadr (aref board pos))))
      (take-all (lazy-mapcar
                  (lambda (move)
                    (let ((path (car move)))
                      (if path
                          (let* ((src (car path))
                                 (dst (cadr path))
                                 (odds (aref (aref *dice-odds* (1- (dice dst)))
                                             (- (dice src) 2))))
                            (+ (* odds (rate-position (cadr move) player))
                               (* (- 1 odds) (rate-position (caddr move) player))))
                          (rate-position (cadr move) player))))
                  (caddr tree))))))

(defun limit-tree-depth (tree depth)
  (list (car tree)
        (cadr tree)
        (if (zerop depth)
            (lazy-nil)
            (lazy-mapcar (lambda (move)
                           (cons (car move)
                                 (mapcar (lambda (x)
                                           (limit-tree-depth x (1- depth)))
                                         (cdr move))))
                         (caddr tree)))))

(defparameter *ai-level* 2)

(defun handle-computer (tree)
  (let ((ratings (get-ratings (limit-tree-depth tree *ai-level*) (car tree))))
    (pick-chance-branch (cadr tree)
                        (lazy-nth (position (apply #'max ratings) ratings) (caddr tree)))))

(defun play-vs-computer (tree)
  (print-info tree)
  (cond ((lazy-null (caddr tree)) (announce-winner (cadr tree)))
        ((zerop (car tree)) (play-vs-computer (handle-human tree)))
        (t (play-vs-computer (handle-computer tree)))))

(defparameter *dice-odds* #(#(0.84 0.97 1.0  1.0)
                            #(0.44 0.78 0.94 0.99)
                            #(0.15 0.45 0.74 0.91)
                            #(0.04 0.19 0.46 0.72)
                            #(0.01 0.06 0.22 0.46)))

(let ((old-neighbors (symbol-function 'neighbors))
      (previous (make-hash-table)))
  (defun neighbors (pos)
    (or (gethash pos previous)
      (setf (gethash pos previous) (funcall old-neighbors pos)))))

(let ((old-game-tree (symbol-function 'game-tree))
      (previous (make-hash-table :test #'equalp)))
  (defun game-tree (&rest rest)
    (or (gethash rest previous)
      (setf (gethash rest previous) (apply old-game-tree rest)))))


; SVG UI

(load "svg")

(defmacro svg (width height &body body)
  `(tag svg (xmlns "http://www.w3.org/2000/svg"
             "xmlns:xlink" "http://www.w3.org/1999/xlink"
             height ,height
             width ,width)
        ,@body))

(defparameter *board-width* 900)
(defparameter *board-height* 500)
(defparameter *board-scale* 64)
(defparameter *top-offset* 3)
(defparameter *dice-scale* 40)
(defparameter *dot-size* 0.05)

(defun draw-die-svg (x y col)
  (labels ((calc-pt (pt)
             (cons (+ x (* *dice-scale* (car pt)))
                   (+ y (* *dice-scale* (cdr pt)))))
           (f (pol col)
             (polygon (mapcar #'calc-pt pol) col)))
    (f '((0 . -1) (-0.6 . -0.75) (0 . -0.5) (0.6 . -0.75))
       (brightness col 40))
    (f '((0 . -0.5) (-0.6 . -0.75) (-0.6 . 0) (0 . 0.25))
       col)
    (f '((0 . -0.5) (0.6 . -0.75) (0.6 . 0) (0 . 0.25))
       (brightness col -40))
    (mapc (lambda (x y)
            (polygon (mapcar (lambda (xx yy)
                               (calc-pt (cons (+ x (* xx *dot-size*))
                                              (+ y (* yy *dot-size*)))))
                             '(-1 -1 1 1)
                             '(-1 1 1 -1))
                     '(255 255 255)))
          '(-0.05 0.125 0.3 -0.3 -0.125 0.05 0.2 0.2 0.45 0.45 -0.45 -0.2)
          '(-0.875 -0.80 -0.725 -0.775 -0.70 -0.625 -0.35 -0.05 -0.45 -0.15 -0.45 -0.05))))

(defun draw-tile-svg (x y pos hex xx yy col chosen-tile)
  (loop for z below 2
        do (polygon (mapcar (lambda (pt)
                              (cons (+ xx (* *board-scale* (car pt)))
                                    (+ yy (* *board-scale*
                                             (+ (cdr pt) (* (- 1 z) 0.1))))))
                            '((-1 . -0.2) (0 . -0.5) (1 . -0.2) (1 . 0.2) (0 . 0.5) (-1 . 0.2)))
                    (if (eql pos chosen-tile)
                        (brightness col 100)
                        col)))
  (loop for z below (second hex)
        do (draw-die-svg (+ xx
                            (* *dice-scale*
                               0.3
                               (if (oddp (+ x y z))
                                   -0.3
                                   0.3)))
                         (- yy (* *dice-scale* z 0.8)) col)))

(defparameter *die-colors* '((255 63 63) (63 63 255) (63 255 63) (255 63 255)))

(defun draw-board-svg (board chosen-tile legal-tiles)
  (loop for y below *board-size*
        do (loop for x below *board-size*
                 for pos = (+ x (* *board-size* y))
                 for hex = (aref board pos)
                 for xx = (* *board-scale* (+ (* 2 x) (- *board-size* y)))
                 for yy = (* *board-scale* (+ (* y 0.7) *top-offset*))
                 for col = (brightness (nth (first hex) *die-colors*)
                                       (* -15 (- *board-size* y)))
                 do (if (member pos legal-tiles)
                        (tag g ()
                             (tag a ("xlink:href" (make-game-link pos))
                                  (draw-tile-svg x y pos hex xx yy col chosen-tile)))
                        (draw-tile-svg x y pos hex xx yy col chosen-tile)))))

(defun make-game-link (pos)
  (format nil "/game.html?chosen=~a" pos))


; Web interface (works in Chrome)

(load "webserver")

(defparameter *cur-game-tree* nil)
(defparameter *from-tile* nil)

(defun dod-request-handler (path header params)
  (if (equal path "game.html")
      (progn (princ "<!doctype html>")
             (tag center ()
                  (princ "Welcome to DICE OF DOOM!")
                  (tag br ())
                  (let ((chosen (assoc 'chosen params)))
                    (when (or (not *cur-game-tree*) (not chosen))
                      (setf chosen nil)
                      (web-initialize))
                    (cond ((lazy-null (caddr *cur-game-tree*))
                             (web-announce-winner (cadr *cur-game-tree*)))
                          ((zerop (car *cur-game-tree*))
                             (web-handle-human
                                (when chosen
                                      (read-from-string (cdr chosen)))))
                          (t (web-handle-computer))))
                  (tag br ())
                  (draw-dod-page *cur-game-tree* *from-tile*)))
      (princ "Sorry... I don't know that page.")))

(defun web-initialize ()
  (setf *from-tile* nil)
  (setf *cur-game-tree* (game-tree (gen-board) 0 0 t)))

(defun web-announce-winner (board)
  (fresh-line)
  (let ((w (winners board)))
    (if (> (length w) 1)
        (format t "The game is a tie between ~a. " (mapcar #'player-letter w))
        (format t "The winner is ~a. " (player-letter (car w)))))
  (tag a (href "game.html")
       (princ "play again")))

(defun web-handle-human (pos)
  (cond ((not pos) (princ "Please choose a hex to move from:"))
        ((eq pos 'pass)
         (setf *cur-game-tree* (cadr (lazy-car (caddr *cur-game-tree*))))
         (princ "Your reinforcements have been placed. ")
         (tag a (href (make-game-link nil)) (princ "continue")))
        ((not *from-tile*)
         (setf *from-tile* pos)
         (princ "Now choose a destination:"))
        ((eq pos *from-tile*)
         (setf *from-tile* nil)
         (princ "Move cancelled."))
        (t (setf *cur-game-tree*
                 (cadr (lazy-find-if (lambda (move)
                                       (equal (car move)
                                              (list *from-tile* pos)))
                                     (caddr *cur-game-tree*))))
           (setf *from-tile* nil)
           (princ "You may now ")
           (tag a (href (make-game-link 'pass))
                (princ "pass"))
           (princ " or make another move:"))))

(defun web-handle-computer ()
  (setf *cur-game-tree* (handle-computer *cur-game-tree*))
  (princ "The computer has moved. ")
  (tag script ()
    (princ "window.setTimeout('window.location=\"game.html?chosen=NIL\"',5000)")))

(defun draw-dod-page (tree selected-tile)
  (svg *board-width*
       *board-height*
       (draw-board-svg (cadr tree)
                       selected-tile
                       (take-all (if selected-tile
                                     (lazy-mapcar
                                       (lambda (move)
                                         (when (eql (caar move) selected-tile)
                                               (cadar move)))
                                       (caddr tree))
                                     (lazy-mapcar #'caar (caddr tree))))))))
