<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="/domain">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:element name="commandline" xmlns="http://libvirt.org/schemas/domain/qemu/1.0">
              <arg value="-fw_cfg"/>
              <!-- THE PATH in file= IS USED BY DEFAULT LIBVIRT POOL -->
              <arg value="name=opt/org.opensuse.combustion/script,file=/var/lib/libvirt/images/${combustion_filename}"/>
            </xsl:element>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
