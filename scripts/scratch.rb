require 'matrix'

x = [1, 3, -5]
y = [4, -2, -1]

a = Vector[*x]
# a = Vector[1, 3, -5]
b = Vector[*y]
# b = Vector[4, -2, -1]

p a.inner_product(b)
