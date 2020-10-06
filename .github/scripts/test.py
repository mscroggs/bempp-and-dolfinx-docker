import bempp.api
import dolfinx

grid = bempp.api.shapes.cube(h=0.5)

mesh = dolfinx.UnitCubeMesh(2, 2, 2)
