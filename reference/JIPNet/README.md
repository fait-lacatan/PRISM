# JIPNet Extractor Setup

The source code and checkpoints for JIPNet have been removed from this repository to comply with external licensing and attribution requirements.

However, the PRISM application relies on the exact `setup/` folder structure to import the models and the `ckpts/` folder for weights. You must download the following specific files from the original repository:
**[https://github.com/XiongjunGuan/JIPNet/tree/main](https://github.com/XiongjunGuan/JIPNet/tree/main)**

Place the downloaded files into the directories as shown below:

1. **`setup/DeepPrint/`**
   - Download `DeepPrint.py` and place it here.
   - Download `inception.py` and place it here.

2. **`setup/RidgeNet/`**
   - Download `RidgeNet.py` and place it here.
   - Download `units.py` and place it here.

3. **`ckpts/`** (Model Checkpoints)
   - Download the model checkpoints provided by the JIPNet repository.
   - Place `DeepPrint.pth.tar` here.
   - Place `RidgeNet.pth` here.

*Note: The `__init__.py` files inside the setup folders have been preserved to ensure Python recognizes them as modules.*
