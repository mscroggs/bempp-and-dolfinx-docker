import bempp.api
from mpi4py import MPI
import dolfinx

grid = bempp.api.shapes.cube(h=0.5)

mesh = dolfinx.UnitCubeMesh(MPI.COMM_WORLD, 2, 2, 2)
