#############################################################################
# Dockerfile for exercises for the module "Advanced Statistical Inference"
#############################################################################
# Compiling a Docker image from this Dockerfile might take a couple of minutes, mainly due to the installation of LaTeX packages.
# This image lets anyone run RStudio in a web browser, where it is then possible to (1) execute exercise code and (2) compile RMarkdown, Quarto
# or LaTeX documents to PDF. The functionality is independent of your operating system, as everything runs inside a Docker container.

# Start from the official Rocker Tidyverse base image with R version 4.3.3. It already includes R, RStudio Server, the tidyverse packages,
# many basic R packages like MASS, and common system dependencies. For details see https://rocker-project.org/images/versioned/rstudio.html
FROM rocker/tidyverse:4.3.3


#############################################################################
# Install R packages not included in the base image
#############################################################################
# # We could install the 'remotes' package, which allows us to install specific package versions:
# RUN install2.r --error remotes
# # You could then install specific version like this (error prone though!): 
# RUN R -e "remotes::install_version(<package_name>, version = <version_number>, repos = 'https://cloud.r-project.org')"

# Install statistical / modeling utilities
RUN R -e "install.packages(c('MCMCpack', 'invgamma'))"
# Install data handling and visualization stack
RUN R -e "install.packages(c('ggpubr', 'car'))"
# Install core document and text packages
RUN R -e "install.packages(c('tinytex', 'rmarkdown', 'knitr', 'stringi', 'stringr'))"


# #############################################################################
# # Install TinyTeX *distribution* (actual TeX system)
# #############################################################################
# Run R and install TinyTeX itself together with (might take around 12 minutes)
USER rstudio
RUN R -e "tinytex::install_tinytex(force = TRUE); tinytex::tlmgr_path()" \
 && R -e "tinytex::tlmgr_install(c('collection-latexrecommended','collection-latexextra','collection-fontsrecommended','collection-fontsextra'))" \
 && R -e "tinytex::tlmgr_update()"

 
#############################################################################
# Create latexmkclean wrapper with more desirable attributes
#############################################################################
USER root
RUN cat <<'EOF' >/usr/local/bin/latexmkclean
#!/usr/bin/env bash
set -e

if [[ -z "$1" ]]; then
  echo "Usage: latexmkclean file.tex"
  exit 1
fi

dir=$(dirname "$1")
file=$(basename "${1%.tex}")

(
  cd "$dir" || exit 1

  echo "Compiling $file.tex ..."
  latexmk -pdf -interaction=nonstopmode "$file.tex"

  echo "Cleaning with latexmk ..."
  latexmk -c "$file.tex"

  echo "Removing extra artifacts tied to $file ..."
  for ext in aux log toc lof lot fls fdb_latexmk out \
             bbl blg bcf run.xml \
             idx ilg ind \
             nav snm \
             synctex.gz \
             tmp temp md5 xr \
             pytxcode pytxpy pytxmcr
  do
    rm -f "${file}.${ext}"
  done

  echo "Removing all .cut files in this directory ..."
  rm -f ./*.cut

  # Optional: remove latexmk's working directory
  rm -rf _latexmk

  echo "Cleanup done."
)
EOF

RUN chmod +x /usr/local/bin/latexmkclean


#############################################################################
# Expose port and disable authentication
#############################################################################

# Expose port 8787, which is the default port for RStudio Server.
EXPOSE 8787
ENV DISABLE_AUTH=true