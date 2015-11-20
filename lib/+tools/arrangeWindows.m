function arrangeWindows(aoWindows)
%ARRANGEWINDOWS Arranges figure windows for better user experience
%   This function arranges any number of windows between 1 and 15 in a 
%   regular pattern for any screen size.
%   All additional windows will be stacked in the default location.

% Getting the number of windows
if nargin < 1 || isempty(aoWindows)
    aoWindows = flipud(get(0,'Children'));
end
iNumberOfWindows = length(aoWindows);

% if there are 3 windows or less, do nothing.
if iNumberOfWindows < 4
    return;
elseif iNumberOfWindows < 11
    % For up to 8 windows, use two horizontal rows
    iNumberOfRows = 2;
else
    % For more than 8 windows, use three horizontal rows
    iNumberOfRows = 3;
end

% Four rows is just too much. Use less windows. :-)

% Determine the number of columns. If the number of windows is uneven, the bottom right
% area will be left empty.
if mod(iNumberOfWindows, iNumberOfRows)
    iNumberOfColumns = ceil(iNumberOfWindows/iNumberOfRows);
    if iNumberOfColumns > 5, iNumberOfColumns = 5; end;
else
    iNumberOfColumns = iNumberOfWindows / iNumberOfRows;
end


% Handle multiple screens: plot where the Matlab main window is positioned!
% NOTE: assuming  that multiple displays are positioned left/right, not
% above/below of each other, i.e. only comparing the x-positions.
aScreenSizes = get(0, 'MonitorPositions');
afPositionsX = sort(aScreenSizes(:, 1));
afMainWinPos = get(0, 'Pointer');

% Sort X-coordinates of displays ASC, find all display coordinates that are
% smaller than the main window X-coordinate and get the largest of those.
% Use that X-coordinate to find the appropiate row in monitor positions.
iScreen      = find(max(afPositionsX(afMainWinPos(1) > afPositionsX)) == aScreenSizes(:, 1));
aScreenSize  = aScreenSizes(iScreen, :);


if ismac
    aScreenSize(4) = aScreenSize(4) - 23;
end

iWidth  = floor( aScreenSize(3) / iNumberOfColumns );
iHeight = floor( aScreenSize(4) / iNumberOfRows );

iLeft   = aScreenSize(1);
iBottom = (iNumberOfRows - 1) * iHeight + aScreenSize(2);
iWindow = 1;

for iJ = 1:iNumberOfRows
    for iK = 1:iNumberOfColumns
        aPosition = [iLeft, iBottom + 1, iWidth, iHeight];
        if iWindow > iNumberOfWindows
            return;
        else
            set(aoWindows(iWindow), 'OuterPosition', aPosition);
            iLeft = iLeft + iWidth;
            
            % On Macs, the default screen resolution is 72 ppi. Since 
            % MATLAB 2015b, this can no longer be changed by the user. On 
            % Windows this number is 96 ppi. The reason this is done in the 
            % first place is to make the fonts larger for better screen 
            % viewing. So now we have to do the workaround of setting the 
            % figure's font size higher. Default is 8 (or 10?), we want it
            % to be at 12.
            if ismac
                oAxes = aoWindows(iWindow).CurrentAxes;
                set(oAxes,'FontSize',12);
            end
            
            % Finally we have to increment the window counter
            iWindow = iWindow + 1;
        end
    end
    
    iLeft = aScreenSize(1);
    iBottom = iBottom - iHeight;
end

drawnow();

end

