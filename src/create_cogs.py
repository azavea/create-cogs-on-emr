"""
A PySpark script that converts raster images to COGss.
Edit the settings at the top to tune how many concurrent images to process per machine.
Edit get_input_and_output_paths to return the input rasters mapped to their desired COG locations.
Edit gdal_cog_commands to modify any GDAL settings to make the COGs you want.
"""
import os
import tempfile
import shutil
from urlparse import urlparse
from subprocess import Popen, PIPE

NUM_PARTITIONS = 50

# Fill this out for your particular job.
def get_input_and_output_paths():
    """
    Return a list of tuples of  (input_uri, output_uri).
    URIs can be local paths or S3 paths.
    """
    import boto3

    bucket = 'spacenet-dataset'
    prefix = 'mvs_dataset/WV3/MSI/'

    def target_from_source(uri):
        base_name = os.path.splitext(os.path.basename(uri))[0]
        return "s3://azavea-research-emr/cog-creator/spacenet/test/{}.TIF".format(base_name)

    s3 = boto3.client('s3')
    list_result = s3.list_objects(Bucket=bucket, Prefix=prefix, Delimiter='/')

    result = []
    for o in list_result['Contents']:
        key = o['Key']
        if key.endswith('NTF'):
            result.append(("s3://{}/{}".format(bucket, key),
                           target_from_source(key)))

    return result[:15]

# Edit this if you want control of how the COGs are created.
def gdal_cog_commands(input_path, tmp_dir):
    """
    GDAL commands to  create a COG from an input file.
    Modify here if  you want diffent options or processes.
    Returns a tuple (commands, output_path)
    """
    def get_output_path(command):
        fname = os.path.splitext(os.path.basename(input_path))[0]
        return os.path.join(tmp_dir, "{}-{}.tif".format(fname, command))


    ## Step 1: Translate to a GeoTiff.
    translate_path = get_output_path("translate")
    translate = ["gdal_translate",
                 "-of", "GTiff",
                 "-co", "tiled=YES",
                 input_path,
                 translate_path]

    ## Step 2: Add overviews
    overviews = [2, 4, 8, 16, 32]

    add_overviews = ["gdaladdo",
                     "-r", "bilinear",
                     translate_path] + list(map(lambda x: str(x), overviews))

    ## Step 3: Translate to COG
    output_path = get_output_path("cog")

    create_cog = ["gdal_translate",
                  "-co", "TILED=YES",
                  "-co", "COMPRESS=deflate",
                  "-co", "COPY_SRC_OVERVIEWS=YES",
                  "-co", "BLOCKXSIZE=512",
                  "-co", "BLOCKYSIZE=512",
                  "--config", "GDAL_TIFF_OVR_BLOCKSIZE", "512",
                  translate_path,
                  output_path]

    return ([translate,
             add_overviews,
             create_cog], output_path)

## Utility Methods and the run command ##

def do_run(cmd):
    p = Popen(cmd)
    (out,err) = p.communicate(input)
    if p.returncode != 0:
        s = "Command failed:\n"
        s += ' '.join(cmd) + "\n\n"
        if out:
            s += out + "\n\n"
        if err:
            s += err
        raise Exception(s)

def target_partition_count(number_of_images):
    return min(number_of_images, NUM_PARTITIONS)

def makedirs_p(d):
    if not os.path.exists(d):
        os.makedirs(d)
    return d

def create_tmp_directory(prefix):
    tmp = tempfile.mktemp(prefix=prefix, dir=os.path.join(os.environ['PWD'], "cog-temp"))
    return makedirs_p(tmp)

def get_local_copy(uri, local_dir):
    parsed = urlparse(uri)
    local_path = tempfile.mktemp(dir=local_dir)
    if parsed.scheme == "s3":
        cmd = ["aws", "s3", "cp", uri, local_path]
    elif parsed.scheme == "http":
        cmd = ["wget", "-O", local_path, uri]
    else:
        cmd = ["cp", uri, local_path]

    do_run(cmd)

    return local_path

def upload_to_dest(local_src, dest):
    parsed = urlparse(dest)

    if parsed.scheme == "s3":
        cmd = ["aws", "s3", "cp",
               "--content-type", "image/tiff",
               local_src, dest]
    else:
        d = os.path.dirname(dest)
        if not os.path.exists(d):
            os.makedirs(d)
        cmd = ["cp", local_src, dest]

    do_run(cmd)

    return dest

def create_cog(source_uri, dest, local_dir):
    local_path = get_local_copy(source_uri, local_dir)

    commands, output_path = gdal_cog_commands(local_path, local_dir)
    for command in commands:
        do_run(command)

    upload_to_dest(output_path, dest)

def create_cogs(partition):
    partition = list(partition)
    if not partition:
        raise Exception("EMPTY PARTITION")

    if len(partition) > 1:
        raise Exception("TOO MANY IN PARTITION {}".format(len(partition)))
    local_dir = create_tmp_directory("cog-creator")
    try:
        for (source_uri, dest) in partition:
            create_cog(source_uri, dest, local_dir)
        shutil.rmtree(local_dir)
    finally:
        if local_dir:
            shutil.rmtree(local_dir, ignore_errors=True)

def run_spark_job():
    from pyspark import SparkConf, SparkContext

    image_uris = get_input_and_output_paths()

    conf = SparkConf().setAppName("Spark COG Generator")
    sc = SparkContext(conf=conf)

    sc.parallelize(enumerate(image_uris)) \
      .partitionBy(target_partition_count(len(image_uris))) \
      .map(lambda (i, v): v) \
      .foreachPartition(create_cogs)

    print "Done."

if __name__ == "__main__":
    run_spark_job()
