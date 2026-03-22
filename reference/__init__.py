try:
    from .JIPNet.setup.DeepPrint.DeepPrint import DeepPrint_stn
    from .JIPNet.setup.RidgeNet.RidgeNet import RidgeNet
    from .JIPNet.setup.RidgeNet.units import orientation_highest_peak, select_max_orientation
except ImportError:
    pass
